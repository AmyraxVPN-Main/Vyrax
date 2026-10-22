import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';

import 'models.dart';
import 'xray_config.dart';

class XrayProvisionException implements Exception {
  const XrayProvisionException(this.reason);
  final String reason;

  @override
  String toString() => 'XrayProvisionException($reason)';
}

class SpoofEngineState {
  final bool running;
  final int servers;
  final String? failure;
  final int probeMs;
  final String? exitCountry;
  final String? exitIp;

  const SpoofEngineState({
    this.running = false,
    this.servers = 0,
    this.failure,
    this.probeMs = 0,
    this.exitCountry,
    this.exitIp,
  });

  SpoofEngineState copyWith({
    bool? running,
    int? servers,
    String? failure,
    bool clearFailure = false,
    int? probeMs,
    String? exitCountry,
    String? exitIp,
  }) => SpoofEngineState(
    running: running ?? this.running,
    servers: servers ?? this.servers,
    failure: clearFailure ? null : (failure ?? this.failure),
    probeMs: probeMs ?? this.probeMs,
    exitCountry: exitCountry ?? this.exitCountry,
    exitIp: exitIp ?? this.exitIp,
  );
}

class SpoofProbeResult {
  final bool ok;
  final int elapsedMs;
  final String? exitCountry;
  final String? exitIp;

  const SpoofProbeResult({
    required this.ok,
    required this.elapsedMs,
    this.exitCountry,
    this.exitIp,
  });
}

class _XraySession {
  final String key;
  final Process process;
  final int socksPort;
  final int httpPort;
  final File configFile;

  _XraySession({
    required this.key,
    required this.process,
    required this.socksPort,
    required this.httpPort,
    required this.configFile,
  });
}

class SpoofEngine {
  static const xrayVersion = '26.3.27';
  static const xraySha256 =
      'd004c39288ce9ada487c6f398c7c545f7d749e44bdfdd59dbc9f865afba4e1ad';
  static const xrayUrl =
      'https://github.com/XTLS/Xray-core/releases/download/'
      'v$xrayVersion/Xray-windows-64.zip';
  static const _filesToExtract = ['xray.exe', 'geoip.dat', 'geosite.dat'];
  static const _startTimeout = Duration(seconds: 10);
  static const _portProbeTimeout = Duration(milliseconds: 200);

  final Future<Directory> Function() dataDir;
  final Map<String, _XraySession> _sessions = {};
  List<String> logLines = [];
  final ValueNotifier<SpoofEngineState> state = ValueNotifier(
    const SpoofEngineState(),
  );

  int? _exitCode;
  String _lastErrorLog = '';

  SpoofEngine(this.dataDir);

  bool get isRunning => _sessions.isNotEmpty;

  List<String> get sessionKeys => _sessions.keys.toList();

  Future<String> get binaryDir => dataDirRelative('xray');

  Future<String> dataDirRelative(String name) async =>
      join((await dataDir()).path, name);

  String get xrayExecutableName => Platform.isWindows ? 'xray.exe' : 'xray';

  Future<String> get xrayPath async =>
      join(await binaryDir, xrayExecutableName);

  Future<bool> isInstalled() async => File(await xrayPath).exists();

  Future<String?> installedVersion() async {
    final path = await xrayPath;
    if (!await File(path).exists()) return null;
    try {
      final result = await Process.run(path, const ['version']);
      if (result.exitCode != 0) return null;
      final match = RegExp(r'Xray (\S+)').firstMatch(
        result.stdout.toString(),
      );
      return match?.group(1);
    } on ProcessException {
      return null;
    }
  }

  Future<void> install({void Function(double progress)? onProgress}) async {
    final directory = Directory(await binaryDir);
    await directory.create(recursive: true);
    final tempZip = File(join(await binaryDir, 'xray-download.zip'));
    final dio = Dio(
      BaseOptions(headers: {'user-agent': 'Vyrax/$xrayVersion'}),
    );
    try {
      await dio.download(
        xrayUrl,
        tempZip.path,
        onReceiveProgress: (received, total) {
          final progress = onProgress;
          if (progress != null && total > 0) progress(received / total);
        },
      );
    } on DioException catch (error) {
      throw XrayProvisionException('download ${error.message}');
    }
    final bytes = await tempZip.readAsBytes();
    final digest = sha256.convert(bytes).toString();
    if (digest != xraySha256) {
      await tempZip.delete();
      throw XrayProvisionException('checksum $digest');
    }
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final entry in archive.files) {
      final fileName = basename(entry.name).toLowerCase();
      if (!_filesToExtract.contains(fileName) || !entry.isFile) continue;
      final out = File(join(await binaryDir, fileName));
      await out.writeAsBytes(entry.content);
    }
    await tempZip.delete();
    final installed = await installedVersion();
    if (installed == null) {
      throw const XrayProvisionException('version');
    }
  }

  Future<bool> _portBusy(int port) async {
    ServerSocket? socket;
    try {
      socket = await ServerSocket.bind('127.0.0.1', port);
      return false;
    } on SocketException {
      return true;
    } finally {
      await socket?.close();
    }
  }

  Future<List<int>> _allocatePorts() async {
    var base = kSpoofSocksPort;
    final found = <int>[];
    while (found.length < 2 && base < kSpoofSocksPort + 2048) {
      if (base == kSpoofDefaultUdpPort) {
        base++;
        continue;
      }
      if (await _portBusy(base)) {
        base++;
        continue;
      }
      found.add(base);
      base++;
    }
    if (found.length < 2) {
      throw const XrayProvisionException('ports');
    }
    return found;
  }

  Future<void> startServer(
    String key,
    SpoofProfile profile, {
    bool iranDirect = true,
  }) async {
    final binary = await xrayPath;
    if (!await File(binary).exists()) {
      throw const XrayProvisionException('missing-binary');
    }
    await stopSession(key);
    final ports = await _allocatePorts();
    final socksPort = ports.first;
    final httpPort = ports.last;
    _exitCode = null;
    _lastErrorLog = '';
    final config = buildSpoofXrayConfig(
      profile: profile,
      socksPort: socksPort,
      httpPort: httpPort,
      iranDirect: iranDirect,
    );
    final dir = await binaryDir;
    final configFile = File(join(dir, 'xray-$key.json'));
    await configFile.writeAsString(jsonEncode(config), flush: true);
    Process process;
    try {
      process = await Process.start(binary, ['-c', configFile.path]);
    } on ProcessException catch (error) {
      throw XrayProvisionException('spawn ${error.message}');
    }
    final session = _XraySession(
      key: key,
      process: process,
      socksPort: socksPort,
      httpPort: httpPort,
      configFile: configFile,
    );
    try {
      process.stdout.transform(utf8.decoder).listen(_appendLog);
      process.stderr.transform(utf8.decoder).listen(_appendLog);
      unawaited(
        process.exitCode.then((code) => _onExit(session, code)),
      );
      _sessions[key] = session;
      await _waitForPorts(session);
    } catch (_) {
      _sessions.remove(key);
      final failing = File(join(dir, 'xray-fail.json'));
      await configFile.copy(failing.path);
      await stopSession(key);
      rethrow;
    }
    _refreshState();
  }

  void _onExit(_XraySession session, int code) {
    if (identical(_sessions[session.key]?.process, session.process)) {
      _sessions.remove(session.key);
      _refreshState();
    }
    _exitCode = code;
    if (_lastErrorLog.isEmpty) {
      _lastErrorLog = logLines
          .where((line) => line.contains('Failed to start'))
          .join(' ');
    }
  }

  void _appendLog(String chunk) {
    logLines.add(chunk);
    for (final line in chunk.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.contains('[Error]') || trimmed.contains('Failed to start')) {
        _lastErrorLog = trimmed;
      }
    }
    if (logLines.length > 500) {
      logLines.removeRange(0, logLines.length - 500);
    }
  }

  void _refreshState() {
    final running = _sessions.isNotEmpty;
    state.value = state.value.copyWith(
      running: running,
      servers: _sessions.length,
    );
  }

  (int, int) portsOf(String key) {
    final session = _sessions[key];
    if (session == null) return (0, 0);
    return (session.socksPort, session.httpPort);
  }

  Future<void> _waitForPorts(_XraySession session) async {
    final deadline = DateTime.now().add(_startTimeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_sessions[session.key] == null) {
        throw XrayProvisionException(_spawnFailure());
      }
      try {
        final socket = await Socket.connect(
          '127.0.0.1',
          session.socksPort,
          timeout: _portProbeTimeout,
        );
        await socket.close();
        return;
      } on SocketException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    throw const XrayProvisionException('timeout');
  }

  String _spawnFailure() {
    final code = _exitCode;
    final error = _lastErrorLog.trim();
    final parts = [
      if (code != null) 'exit code $code',
      if (error.isNotEmpty)
        error.length > 200 ? '…${error.substring(error.length - 200)}' : error,
    ];
    return parts.isEmpty ? 'spawn' : parts.join(' · ');
  }

  HttpClient createProbeClient(int httpPort) {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    client.findProxy = (uri) => 'PROXY 127.0.0.1:$httpPort';
    return client;
  }

  Future<void> stopSession(String key) async {
    final session = _sessions.remove(key);
    if (session != null) {
      final process = session.process;
      process.kill(ProcessSignal.sigterm);
      try {
        await process.exitCode.timeout(const Duration(seconds: 5));
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
      }
      final configFile = session.configFile;
      if (await configFile.exists()) {
        await configFile.delete();
      }
    }
    _refreshState();
  }

  Future<void> stopAll() async {
    for (final key in List.of(_sessions.keys)) {
      await stopSession(key);
    }
    final failing = File(join(await binaryDir, 'xray-fail.json'));
    if (await failing.exists()) {
      await failing.delete();
    }
    state.value = state.value.copyWith(
      running: false,
      servers: 0,
      exitCountry: null,
      exitIp: null,
      probeMs: 0,
    );
  }
}
