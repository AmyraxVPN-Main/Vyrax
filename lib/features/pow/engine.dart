import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show min;

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import 'models.dart';

class PowEngineException implements Exception {
  final String message;

  const PowEngineException(this.message);

  @override
  String toString() => message;
}

Future<bool> tcpAccepts(
  int port, {
  Duration timeout = const Duration(milliseconds: 800),
}) async {
  try {
    final socket = await Socket.connect(
      '127.0.0.1',
      port,
      timeout: timeout,
    );
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

/// End-to-end health check of the exit SOCKS: performs a real SOCKS5
/// CONNECT to 1.1.1.1:443 through the tunnel, so a listening-but-dead
/// upstream (server gone offline after a while) reports as failed.
///
/// The two answers (greeting + CONNECT reply) are read by a single
/// subscription with a cumulative buffer: separate `_readAtLeast` reads
/// would cancel-and-relisten and silently drop the tail bytes when TCP
/// coalesces both answers into one chunk, so a perfectly healthy fast
/// tunnel would hang its second read and wrongly time out. A healthy
/// tunnel keeps the socket open, which this probe never waits for.
Future<bool> probeExitSocks(
  int port, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  Socket? socket;
  StreamSubscription<Uint8List>? sub;
  try {
    socket = await Socket.connect(
      '127.0.0.1',
      port,
      timeout: timeout,
    );
    final live = socket;
    live.setOption(SocketOption.tcpNoDelay, true);
    // Greeting requirement: replies always begin after the client's
    // greeting (2 bytes), and the CONNECT reply (10 bytes, IPv4) always
    // follows — cumulative 12 bytes covers both coalesced and split
    // deliveries, whatever the chunk boundaries are.
    live.add([0x05, 0x01, 0x00]);
    final completer = Completer<bool>();
    final observed = <int>[];
    var answered = false;
    late final StreamSubscription<Uint8List> localSub;
    localSub = live.listen((chunk) {
      if (completer.isCompleted) return;
      observed.addAll(chunk);
      if (!answered) {
        if (observed.length < 2) return;
        if (observed[0] != 0x05 || observed[1] != 0x00) {
          localSub.cancel();
          completer.complete(false);
          return;
        }
        live.add([
          0x05, 0x01, 0x00, 0x01, //
          0x01, 0x01, 0x01, 0x01, 0x01, 0xBB,
        ]);
        answered = true;
        return;
      }
      // The tunnel is healthy when the upstream CONNECT replies success
      // (reply byte at cumulative offset 3) — the proxy's own traffic
      // follows on the same wire, so only the reply header is awaited.
      if (observed.length >= 12) {
        localSub.cancel();
        completer.complete(observed[3] == 0x00);
      }
    });
    sub = localSub;
    return await completer.future.timeout(
      timeout,
      onTimeout: () => false,
    );
  } catch (_) {
    return false;
  } finally {
    await sub?.cancel();
    socket?.destroy();
  }
}

/// Polls the TCP port (stateless wait) until ready or the wait is cancelled.
Future<bool> waitTcpReady(
  int port,
  Duration budget,
  bool Function() cancelled, {
  Future<bool> Function()? stillRunning,
}) async {
  final deadline = DateTime.now().add(budget);
  while (DateTime.now().isBefore(deadline)) {
    if (cancelled()) return false;
    if (stillRunning != null && !await stillRunning()) return false;
    if (await tcpAccepts(port)) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (cancelled()) return false;
      if (stillRunning != null && !await stillRunning()) return false;
      if (await tcpAccepts(port)) return true;
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  return false;
}

/// Maps a chainOuterJson payload onto the aether CLI environment.
Map<String, String> jsonToEnv(Map<String, Object?> payload) {
  final env = <String, String>{};
  final configPath = payload['config_path'];
  if (configPath is String && configPath.isNotEmpty) {
    env['AETHER_CONFIG'] = configPath;
  }
  final protocol = '${payload['protocol'] ?? 'masque'}'.toLowerCase();
  env['AETHER_PROTOCOL'] = switch (protocol) {
    'wireguard' => 'wg',
    'gool' => 'gool',
    _ => 'masque',
  };
  final listen = payload['listen'];
  if (listen is String && listen.isNotEmpty) {
    env['AETHER_SOCKS'] = listen;
  }
  final scanMode = payload['scan_mode'];
  if (scanMode is String && scanMode.isNotEmpty) {
    env['AETHER_SCAN'] = scanMode;
  }
  final ipScan = '${payload['ip_scan'] ?? ''}'.toLowerCase();
  if (ipScan == 'v4' || ipScan == 'v6' || ipScan == 'both') {
    env['AETHER_IP'] = ipScan;
  }
  final obfuscation = payload['obfuscation_profile'];
  if (obfuscation is String && obfuscation.isNotEmpty) {
    env['AETHER_NOIZE'] = obfuscation;
  }
  if ('${payload['masque_transport'] ?? ''}'.toLowerCase() == 'h2') {
    env['AETHER_MASQUE_HTTP2'] = '1';
  }
  if (payload['h2_fragmentation'] == true) {
    env['AETHER_MASQUE_H2_FRAGMENT'] = '1';
  }
  final apiCamo = '${payload['api_camo'] ?? ''}'.trim().toLowerCase();
  if (const {keyAuto, keyEch, keyFragment, keyExternal}.contains(apiCamo)) {
    env['AETHER_API_CAMO'] = apiCamo;
  }
  final discovery = '${payload['endpoint_discovery'] ?? ''}'.trim().toLowerCase();
  if (const {'cache', 'fresh', 'clean', 'saved'}.contains(discovery)) {
    env['AETHER_DISCOVERY'] = discovery;
  }
  final cachePath = payload['endpoint_cache_path'];
  if (cachePath is String && cachePath.isNotEmpty) {
    env['AETHER_MASQUE_CACHE'] = cachePath;
  }
  const routedKeys = <String>[
    'log_level',
    'perf_profile',
    'tls_curve_preset',
    'dns_servers',
    'route_block',
    'route_direct',
    'routes_file',
    'team',
    'access_client_id',
    'access_client_secret',
    'access_token',
    'access_email',
  ];
  for (final key in routedKeys) {
    final value = payload[key];
    if (value != null && (value is! String || value.isNotEmpty)) {
      env['AETHER_${key.toUpperCase()}'] = '$value';
    }
  }
  if (payload['gateway'] == true) {
    env['AETHER_GATEWAY'] = '1';
  }
  if (payload['renew_masque'] == true) {
    env['AETHER_RENEW_CERT'] = '1';
  }
  return env;
}

/// Drops the `HH:MM:SS  ` prefix aether writes in `aether-core.log`.
String coreLogMessage(String raw) {
  final text = raw.trim();
  if (text.length >= 10 &&
      text[2] == ':' &&
      text[5] == ':' &&
      text.substring(8, 10) == '  ') {
    return text.substring(10).trim();
  }
  return text;
}

Future<int> _fileSizeOrNull(File file) async {
  try {
    return await file.exists() ? await file.length() : 0;
  } on FileSystemException {
    return 0;
  }
}

/// Streams NEW lines of a growing log file (follow_core_log analogue).
Future<void> followCoreLog(
  File file,
  bool Function() cancelled,
  void Function(String line) onLine,
) async {
  var offset = await _fileSizeOrNull(file);
  var pending = '';
  while (!cancelled()) {
    final size = await _fileSizeOrNull(file);
    if (size < offset) offset = 0;
    if (size == 0 || size == offset) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      continue;
    }
    RandomAccessFile handle;
    try {
      handle = await file.open(mode: FileMode.read);
    } on FileSystemException {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      continue;
    }
    try {
      await handle.setPosition(offset);
      final bytes = await handle.read(size - offset);
      offset = await handle.position();
      pending += utf8.decode(bytes, allowMalformed: true);
      while (pending.contains('\n')) {
        final index = pending.indexOf('\n');
        final line = pending.substring(0, index);
        pending = pending.substring(index + 1);
        final message = coreLogMessage(line);
        if (message.isEmpty) continue;
        onLine(message);
      }
    } on FileSystemException {
      // transient IO error; retry next cycle
    } finally {
      try {
        await handle.close();
      } on FileSystemException {
        // ignore
      }
    }
  }
  final rest = coreLogMessage(pending);
  if (rest.isNotEmpty) {
    onLine(rest);
  }
}

/// Bundled helper names with their pinned SHA-256 digests.
class PowBinaries {
  static const aether = 'aether.exe';
  static const psiphon = 'uac-psiphon.exe';
  static const singBox = 'sing-box.exe';
  static const cronet = 'libcronet.dll';
  static const serverEntries = 'pow_server_entries.txt';
  static const singBoxLicense = 'sing-box-LICENSE';

  static const singBoxVersion = '1.13.14';
  static const aetherVersion = '1.6.0';

  static const shas = <String, String>{
    aether:
        '2308114e7885d13925de88fa5f897596cc164187de91a091499f2b721387ffbf',
    psiphon:
        '0ee79a117c2355ef27fedd906d0740c7648583b23964437ea7e8ff54214b8996',
    singBox:
        'db0d779948214cf761011d154c3a5da36df20394fa01a9fc798f1dc39fe9d183',
    cronet:
        'c7434cfa93c3041321dd19111c4de6c52b8a9531a65661ba45425d3c51ec69e2',
    serverEntries: '',
    singBoxLicense: '',
  };

  static const bundled = [
    aether,
    psiphon,
    singBox,
    cronet,
    serverEntries,
    singBoxLicense,
  ];
}

/// Extracts the bundled PoW helpers from the app assets into the data dir,
/// verifying each pinned digest. Already-correct files are kept.
Future<void> installPowBinaries(
  Directory dataDir, {
  void Function(double progress)? onProgress,
}) async {
  await dataDir.create(recursive: true);
  final total = PowBinaries.bundled.length;
  for (var i = 0; i < total; i++) {
    final name = PowBinaries.bundled[i];
    final target = File(path.join(dataDir.path, name));
    if (await _upToDate(name, target)) {
      onProgress?.call((i + 1) / total);
      continue;
    }
    ByteData assetData;
    try {
      assetData = await rootBundle.load('assets/pow/$name');
    } on Exception {
      throw PowEngineException('missing-bundle $name');
    }
    final bytes = assetData.buffer.asUint8List(
      assetData.offsetInBytes,
      assetData.lengthInBytes,
    );
    final sha = sha256.convert(bytes).toString();
    final expected = PowBinaries.shas[name];
    if (expected != null && expected.isNotEmpty && sha != expected) {
      throw PowEngineException('checksum $name');
    }
    await target.writeAsBytes(bytes, flush: true);
    onProgress?.call((i + 1) / total);
  }
}

Future<bool> _upToDate(String name, File target) async {
  try {
    if (!await target.exists()) return false;
  } on FileSystemException {
    return false;
  }
  final expected = PowBinaries.shas[name];
  if (expected == null || expected.isEmpty) return true;
  Digest digest;
  try {
    final bytes = await target.readAsBytes();
    digest = sha256.convert(bytes);
  } on FileSystemException {
    return false;
  }
  return digest.toString() == expected;
}

/// One owned helper subprocess with an aggregate of its recent output.
class PowProcess {
  PowProcess(this.name);

  final String name;
  Process? _process;
  final List<String> _lines = [];
  final _emitter = StreamController<String>.broadcast();
  static const _lineCap = 400;
  bool _draining = false;

  bool get running => _process != null;

  int get pid => _process?.pid ?? 0;

  /// Every line the helper has printed so far plus whatever follows.
  Stream<String> get lines => _emitter.stream;

  List<String> get history => List.unmodifiable(_lines);

  String get lastLine => _lines.isEmpty ? '' : _lines.last;

  Future<void> start({
    required String executable,
    required List<String> args,
    Map<String, String>? env,
    required String workingDirectory,
  }) async {
    await stop();
    final process = await Process.start(
      executable,
      args,
      environment: env ?? const {},
      workingDirectory: workingDirectory,
      runInShell: false,
      mode: ProcessStartMode.normal,
    );
    _process = process;
    _draining = false;
    _pump(process.stdout);
    _pump(process.stderr);
  }

  void _pump(Stream<List<int>> source) {
    source
        .transform(const Utf8Decoder(allowMalformed: true))
        .cast<String>()
        .listen(
          _onChunk,
          onDone: () {},
          onError: (Object _) {},
        );
  }

  void _onChunk(String chunk) {
    for (final raw in LineSplitter.split(chunk)) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      _lines.add(line);
      if (_lines.length > _lineCap) {
        _lines.removeRange(0, _lines.length - _lineCap);
      }
      _emitter.add(line);
    }
  }

  /// Null while the process is running, its exit code after termination.
  Future<int?> exitCodeOrNull() async {
    final process = _process;
    if (process == null) return null;
    try {
      return await process.exitCode.timeout(Duration.zero);
    } on TimeoutException {
      return null;
    }
  }

  /// Keeps the process alive after this object lets go of it.
  void drainAndDetach() {
    final process = _process;
    if (process == null) return;
    _process = null;
    try {
      process.stdout.listen(
        (_) {},
        onDone: () {},
        onError: (Object _) {},
      );
      process.stderr.listen(
        (_) {},
        onDone: () {},
        onError: (Object _) {},
      );
    } on StateError {
      // already done
    }
  }

  /// Kills the whole process tree and waits for a short grace period.
  Future<void> stop() async {
    final process = _process;
    if (process == null) return;
    _process = null;
    _draining = true;
    final code = await exitCodeOrNull();
    if (code != null) {
      _draining = false;
      return;
    }
    if (Platform.isWindows) {
      try {
        await Process.run(
          'taskkill',
          ['/pid', '${process.pid}', '/T', '/F'],
          runInShell: false,
        );
      } catch (_) {
        process.kill();
      }
    } else {
      process.kill();
    }
    try {
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      process.kill();
      try {
        await process.exitCode.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        // abandon
      }
    }
    _draining = false;
  }

  bool get isDraining => _draining;

  @override
  String toString() => name;

  /// Feeds an external source (e.g. a tailed log file) into the same stream.
  void addExternalLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;
    _lines.add(trimmed);
    if (_lines.length > _lineCap) {
      _lines.removeRange(0, _lines.length - _lineCap);
    }
    _emitter.add(trimmed);
  }
}

/// Owns one aether outer-leg subprocess (desktop `pow/runner.py` analogue).
class AetherProcess {
  AetherProcess(this.binDirectory);

  final String binDirectory;
  final _process = PowProcess('aether');
  var _coreLogStop = false;
  var _coreLogTask = Future<void>.value();

  bool get running => _process.running;

  Stream<String> get lines => _process.lines;

  Future<int?> exitCodeOrNull() => _process.exitCodeOrNull();

  Future<void> start({
    required String outerJson,
    required String workingDirectory,
  }) async {
    await stop();
    Map<String, Object?> payload;
    try {
      payload = json.decode(outerJson) as Map<String, Object?>;
    } on FormatException {
      throw const PowEngineException('bad-outer-json');
    }
    final env = jsonToEnv(payload);
    env['AETHER_SCAN_ONCE'] = '1';
    final configPath = '${payload['config_path'] ?? ''}';
    if (configPath.isNotEmpty) {
      _coreLogStop = false;
      final coreLog = File(
        path.join(path.dirname(configPath), 'aether-core.log'),
      );
      final process = _process;
      _coreLogTask = followCoreLog(
        coreLog,
        () => _coreLogStop,
        process.addExternalLine,
      ).then(
        (_) {},
        onError: (Object _) {},
      );
    }
    await _process.start(
      executable: path.join(binDirectory, PowBinaries.aether),
      args: const [],
      env: env,
      workingDirectory: workingDirectory,
    );
  }

  /// Waits until the outer SOCKS port answers under [budget].
  Future<bool> waitReady(int port, Duration budget, bool Function() cancelled) {
    return waitTcpReady(
      port,
      budget,
      cancelled,
      stillRunning: () async => await _process.exitCodeOrNull() == null,
    );
  }

  Future<void> stop() async {
    _coreLogStop = true;
    await _coreLogTask;
    await _process.stop();
  }
}

/// Parsed `PSIPHON <json>` notice from the uac-psiphon helper.
class PsiphonNotice {
  const PsiphonNotice(this.kind, this.data);

  final String kind;

  final Map<String, Object?> data;
}

/// Owns one uac-psiphon helper subprocess (`pow/psiphon.py` analogue).
class PsiphonProcess {
  PsiphonProcess(
    this.binDirectory,
    this.serverEntriesPath,
  );

  final String binDirectory;
  final String serverEntriesPath;
  final _process = PowProcess('uac-psiphon');
  final _notices = StreamController<PsiphonNotice>.broadcast();

  bool connected = false;
  int? socksPort;
  String serverRegion = '';
  String clientRegion = '';
  List<String> availableRegions = const [];
  int bytesSent = 0;
  int bytesReceived = 0;
  String lastDiagnostic = '';

  bool get running => _process.running;

  Stream<String> get lines => _process.lines;

  Stream<PsiphonNotice> get notices => _notices.stream;

  Future<void> start({
    required String configJson,
    required String dataDirectory,
    bool meekOnly = false,
  }) async {
    await stop();
    connected = false;
    socksPort = null;
    serverRegion = '';
    clientRegion = '';
    availableRegions = const [];
    bytesSent = 0;
    bytesReceived = 0;
    lastDiagnostic = '';
    final dir = Directory(dataDirectory);
    await dir.create(recursive: true);
    final configPath = path.join(dataDirectory, 'pow-psiphon-config.json');
    await File(configPath).writeAsString(configJson, flush: true);
    final innerDir = path.join(dataDirectory, 'uac-pow-inner');
    await Directory(innerDir).create(recursive: true);
    final args = [
      '-config',
      configPath,
      '-serverList',
      serverEntriesPath,
    ];
    if (meekOnly) {
      args.add('-meekOnly');
    }
    await _process.start(
      executable: path.join(binDirectory, PowBinaries.psiphon),
      args: args,
      workingDirectory: dataDirectory,
    );
    unawaited(
      _process.lines.listen(_handleLine).asFuture<void>().catchError((Object _) {}),
    );
  }

  void _handleLine(String line) {
    if (line.startsWith('PSIPHON ')) {
      _handleNoticeLine(line.substring(8));
    } else if (line.startsWith('PSIPHON')) {
      return;
    } else {
      _emit('log', {'message': line.substring(0, min(line.length, 300))});
    }
  }

  void _emit(String kind, Map<String, Object?> data) {
    _notices.add(PsiphonNotice(kind, data));
  }

  void _handleNoticeLine(String payload) {
    Object? decoded;
    try {
      decoded = json.decode(payload);
    } on FormatException {
      _emit('log', {
        'message': payload.substring(0, min(payload.length, 300)),
      });
      return;
    }
    if (decoded is! Map<String, Object?>) return;
    final kind = '${decoded['noticeType'] ?? ''}';
    final dataRaw = decoded['data'];
    final data = dataRaw is Map<String, Object?> ? dataRaw : <String, Object?>{};
    switch (kind) {
      case 'Tunnels':
        final count = data['count'];
        if (count is num && count.toInt() >= 1) {
          connected = true;
        }
      case 'ListeningSocksProxyPort':
        final port = data['port'];
        socksPort = port is num && port.toInt() != 0 ? port.toInt() : null;
      case 'ConnectedServerRegion':
        serverRegion = '${data['region'] ?? ''}';
      case 'ClientRegion':
        clientRegion = '${data['region'] ?? ''}';
      case 'AvailableEgressRegions':
        final regions = data['regions'] ?? data['region'] ?? const [];
        availableRegions = switch (regions) {
          final String region => [region],
          final List list => list
              .map((item) => '$item')
              .where((region) => region.isNotEmpty)
              .toList(),
          _ => const <String>[],
        };
      case 'BytesTransferred':
        final sent = data['sent'];
        final received = data['received'];
        if (sent is num) bytesSent = sent.toInt();
        if (received is num) bytesReceived = received.toInt();
      case 'Diagnostic' || 'ActiveTunnel' || 'ClientUpgradeAvailable':
        var text = json.encode(data);
        if (text.length > 300) {
          text = text.substring(0, 300);
        }
        if (text.isNotEmpty && text != '{}') {
          lastDiagnostic = '$kind: $text';
        }
    }
    _emit(kind, data);
  }

  /// Resolves true once the Tunnels notice reports a live tunnel.
  Future<bool> waitConnected(
    Duration budget,
    bool Function() cancelled,
  ) async {
    final deadline = DateTime.now().add(budget);
    while (DateTime.now().isBefore(deadline)) {
      if (cancelled()) return false;
      if (connected) return true;
      if (!running) return false;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    return connected;
  }

  Future<int?> exitCodeOrNull() => _process.exitCodeOrNull();

  Future<void> stop() async {
    await _process.stop();
  }
}

/// Provisions the key/certificate via `aether --prepare-only`
/// (desktop `prepare_identity` analogue). Returns the addresses JSON.
Future<Map<String, Object?>> prepareIdentity({
  required String binDirectory,
  required String dataDirectory,
  required PowSettings settings,
  required String protocol,
  bool renew = false,
  Duration timeout = const Duration(seconds: keyFetchTimeoutS),
  void Function(String line)? onLog,
  bool Function()? cancelled,
  String? apiCamo,
}) async {
  final raw = renew
      ? certRenewJson(dataDirectory, settings)
      : keyRequestJson(dataDirectory, settings, protocol);
  final payload = jsonDecode(raw) as Map<String, Object?>;
  if (apiCamo != null && apiCamo.isNotEmpty) {
    payload['api_camo'] = apiCamo;
  }
  final env = jsonToEnv(payload);
  env['AETHER_PREPARE_ONLY'] = '1';
  if (renew) {
    env['AETHER_RENEW_CERT'] = '1';
  }
  final args = [
    '--prepare-only',
  ];
  if (renew) {
    args.add('--renew-cert');
  }
  final camo = (apiCamo ?? '${payload['api_camo'] ?? ''}').trim();
  if (camo.isNotEmpty) {
    args.addAll(['--api-camo', camo]);
  }
  final process = PowProcess('aether-prepare');
  var tailCancelled = false;
  var coreLogTask = Future<void>.value();
  if (onLog != null && payload['config_path'] is String) {
    final configPath = payload['config_path'] as String;
    final coreLog = File(path.join(path.dirname(configPath), 'aether-core.log'));
    coreLogTask = followCoreLog(
      coreLog,
      () => tailCancelled || (cancelled?.call() ?? false),
      onLog,
    ).then(
      (_) {},
      onError: (Object _) {},
    );
  }
  await process.start(
    executable: path.join(binDirectory, PowBinaries.aether),
    args: args,
    env: env,
    workingDirectory: dataDirectory,
  );
  final sub = process.lines.listen(onLog ?? (_) {});
  final deadline = DateTime.now().add(timeout);
  int? exitCode;
  Future<void> stopPrepare() async {
    await process.stop();
    unawaited(sub.cancel());
  }

  while (exitCode == null) {
    if (cancelled?.call() ?? false) {
      await stopPrepare();
      throw const PowEngineException('stopped');
    }
    if (DateTime.now().isAfter(deadline)) {
      await stopPrepare();
      throw PowEngineException(
        'key-request timed out after ${timeout.inSeconds}s',
      );
    }
    exitCode = await process.exitCodeOrNull();
    if (exitCode == null) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
  await process.stop();
  tailCancelled = true;
  await coreLogTask;
  unawaited(sub.cancel());
  if (exitCode != 0) {
    final errorLines =
        process.history.where((l) => l.trim().isNotEmpty).toList();
    final detail = errorLines.isEmpty
        ? 'exit $exitCode'
        : errorLines.last.substring(0, min(errorLines.last.length, 300));
    throw PowEngineException('key-request failed: $detail');
  }
  for (final line in process.history.reversed) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) continue;
    Object? parsed;
    try {
      parsed = jsonDecode(trimmed);
    } on FormatException {
      continue;
    }
    if (parsed is Map<String, Object?> && parsed.containsKey('ipv4')) {
      return parsed;
    }
  }
  throw const PowEngineException('key-request produced no addresses');
}
