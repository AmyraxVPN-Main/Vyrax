import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as path;

import 'engine.dart';
import 'models.dart';
import 'status.dart';
import 'store.dart';

const _mciWgBudgetMs = 20000;
const _exitGrace = Duration(seconds: 1);
const _rttpProbeSamples = 3;

class PowEngineError implements Exception {
  const PowEngineError(this.message);

  final String message;

  @override
  String toString() => message;
}

const _networkScript = r'''
$r=Get-NetRoute -DestinationPrefix 0.0.0.0/0 -ErrorAction SilentlyContinue |
Where-Object { $_.InterfaceAlias -notlike 'UAC-Spoofer*' } |
Sort-Object { $_.RouteMetric + $_.InterfaceMetric } | Select-Object -First 1;
if ($r) { $n=Get-NetNeighbor -IPAddress $r.NextHop -ErrorAction SilentlyContinue | Select-Object -First 1;
$p=Get-NetConnectionProfile -InterfaceIndex $r.ifIndex -ErrorAction SilentlyContinue | Select-Object -First 1;
'{0}|{1}|{2}|{3}' -f $r.InterfaceAlias,$r.NextHop,$n.LinkLayerAddress,$p.Name }
''';

/// Reads the next chunk from a socket stream (single chunk per call).
Future<List<int>> _readChunk(Socket sock) {
  final box = Completer<List<int>>();
  late StreamSubscription<List<int>> sub;
  sub = sock.listen(
    (chunk) {
      sub.cancel();
      if (!box.isCompleted) box.complete(chunk);
    },
    onError: (Object _) {
      sub.cancel();
      if (!box.isCompleted) {
        box.completeError(const SocketException('probe failed'));
      }
    },
    onDone: () {
      if (!box.isCompleted) {
        box.completeError(const SocketException('probe closed'));
      }
    },
  );
  return box.future;
}

/// Detects (key, label) for the current uplink: gateway MAC + network profile.
Future<(String, String)> detectNetwork() async {
  List<String> parts = const [];
  try {
    final result = await Process.run(
      'powershell',
      ['-NoProfile', '-NonInteractive', '-Command', _networkScript],
      runInShell: false,
      stdoutEncoding: const Utf8Codec(allowMalformed: true),
      stderrEncoding: const Utf8Codec(allowMalformed: true),
    ).timeout(const Duration(seconds: 8));
    final lines = (result.stdout as String)
        .trim()
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    final last = lines.isEmpty ? '' : lines.last;
    parts = last.isEmpty ? const <String>[] : last.split('|');
  } on Exception {
    parts = const [];
  }
  if (parts.length < 4) {
    return ('default', 'unknown network');
  }
  final alias = parts[0].trim();
  final hop = parts[1].trim();
  final mac = parts[2].trim();
  final profile = parts[3].trim();
  final identity = '${(mac.isNotEmpty ? mac.toLowerCase() : hop.toLowerCase())}|$profile';
  if (mac.isEmpty && hop.isEmpty && profile.isEmpty) {
    return ('default', 'unknown network');
  }
  final key = sha1.convert(utf8.encode(identity)).toString().substring(0, 12);
  final label = profile.isNotEmpty ? profile : (alias.isNotEmpty ? alias : 'network');
  return (key, label);
}

/// PoW connection coordinator (desktop `pow/coordinator.py` analogue).
///
/// Same order of operations as mobile: 1) raise the outer aether leg
/// (MASQUE / gool / wireguard ladder, per-plan budgets, scan-once), 2) start
/// the Psiphon inner hop through it (strategy ladder, remembered winner
/// first, region-pin attempt first), 3) expose the exit — the app builds a
/// mihomo profile pointing at the exit SOCKS, so there is no system-proxy /
/// TUN step here.
class PowCoordinator {
  PowCoordinator(
    this.dataDir,
    this.store, {
    void Function(String message)? logger,
  }) : _log = logger ?? ((_) {}) {
    _aether = AetherProcess(path.join(dataDir.path, 'pow'));
    _psiphon = PsiphonProcess(
      path.join(dataDir.path, 'pow'),
      path.join(dataDir.path, 'pow', PowBinaries.serverEntries),
    );
    _aether.lines.listen(_onNativeLog);
    _psiphon.notices.listen(_onPsiphonNotice);
  }

  final Directory dataDir;
  final PowStore store;
  final void Function(String message) _log;

  final PowStatusStore status = PowStatusStore();

  late final AetherProcess _aether;
  late final PsiphonProcess _psiphon;

  Timer? _watchdog;
  int _epoch = 0;
  int _connectEpoch = 0;
  var _stopFlag = false;

  String _dialing = '';
  String _keyRoute = '';
  var _cleanAnswered = 0;
  String _lastOuterProtocol = '';
  String _wonTransport = '';
  String _wonIp = '';
  String _h3Transport = '';
  var _exitPort = 0;
  var _directPsiphon = false;
  var _warpOnly = false;
  String _exitRegion = '';
  String _outerLabel = '';
  String _networkKey = 'default';
  String _networkLabel = '';
  Completer<void>? _networkReady;

  bool get connected => _exitPort != 0;

  int get exitPort => _exitPort;

  String get exitRegion => _exitRegion;

  /// Invoked as soon as the Psiphon `ConnectedServerRegion` notice lands,
  /// so the profile label can follow the real exit even when the notice
  /// arrives late (or long after the connect flow finished).
  void Function(String region)? onExitRegion;

  String get outerLabelText => _outerLabel;

  String get binaryDirectory => path.join(dataDir.path, 'pow');

  void _emitLog(String message) {
    try {
      _log(message);
    } catch (_) {
      // logging errors never break the connect flow
    }
  }

  void _ensureActive() {
    if (_stopFlag) throw const PowEngineError('stopped');
  }

  bool _stopped() => _stopFlag;

  Future<void> connect(PowSettings rawSettings) async {
    final settings = rawSettings.validated();
    _epoch++;
    _connectEpoch = _epoch;
    await disconnect(quiet: true, epoch: _connectEpoch);
    if (_epoch != _connectEpoch) {
      throw const PowEngineError('stopped');
    }
    await _reclaimExitPorts();
    _stopFlag = false;
    status.reset();
    status.update(PowPhase.starting, 5, 'Starting UAC PoW');
    _dialing = '';
    _h3Transport = '';
    _lastOuterProtocol = '';
    _wonTransport = '';
    _wonIp = '';
    _exitRegion = '';
    _directPsiphon = false;
    _warpOnly = false;
    _networkKey = 'default';
    _networkLabel = '';
    _networkReady = null;
    unawaited(_startNetworkDetect());

    final mci = usesMciFirewall(settings);
    final plan = outerPlan(settings, mci);
    _logSpeedOptions(settings, mci);
    var ordered = _orderLadder(plan.protocols);
    final applied = _applyTransportChoice(settings, plan, ordered);
    ordered = applied.$1;
    final preferred = applied.$2;
    if (ordered.isEmpty) {
      throw const PowEngineError('no WARP transport selected');
    }

    var fastDirect = false;
    if (settings.directPsiphonFirst) {
      fastDirect = await _tryDirectPsiphonFast(settings);
    }
    String? outer;
    if (fastDirect) {
      outer = null;
    } else {
      outer = await _raiseOuterLeg(
        settings,
        plan.protocols,
        ordered,
        mci,
        preferred: preferred,
      );
    }
    if (_stopped()) {
      throw const PowEngineError('stopped');
    }
    final chain = settings.chainPsiphon;
    if (!chain && outer == null) {
      status.update(PowPhase.failed, 0, 'WARP did not come up');
      throw const PowEngineError('WARP did not come up');
    }

    if (!chain) {
      final outerName = outer ?? 'WARP';
      _warpOnly = true;
      _exitPort = kPowChainSocksPort;
      _outerLabel = outerName;
    } else {
      _directPsiphon = outer == null;
      final outerName = outer ?? 'Psiphon';
      if (_directPsiphon && !fastDirect) {
        _emitLog('No WARP transport came up; Psiphon will connect on its own');
      }
      _ensureActive();
      status.update(
        PowPhase.inner,
        55,
        _directPsiphon
            ? 'Starting Psiphon directly'
            : 'Starting Psiphon through $outerName',
        outerLabel: outerName,
      );
      _outerLabel = outerName;
      if (!fastDirect) {
        await _startPsiphonTunnel(settings);
      }
      _exitPort = kPowPsiphonSocksPort;
    }

    _ensureActive();
    if (!await tcpAccepts(_exitPort)) {
      await Future<void>.delayed(_exitGrace);
    }
    if (!await tcpAccepts(_exitPort)) {
      status.update(PowPhase.failed, 0, 'exit proxy is not listening');
      throw const PowEngineError('exit proxy is not listening');
    }
    status.update(PowPhase.bridging, 88, 'Exposing the UAC PoW exit');

    store.saveLastConnect(
      PowLastConnect(
        protocol: chain && _directPsiphon
            ? 'psiphon'
            : (_lastOuterProtocol.isNotEmpty ? _lastOuterProtocol : 'psiphon'),
        transport: _wonTransport,
        ip: _wonIp,
        peer: '',
        throughPsiphon: chain,
        region: _exitRegion,
      ),
    );
    final ready = settings.chainPsiphon
        ? (_directPsiphon
            ? 'UAC PoW ready · Tunnel through Psiphon'
            : 'UAC PoW ready · Tunnel through Psiphon over '
                '$_outerLabel')
        : 'UAC PoW ready · WARP only';
    status.update(
      PowPhase.connected,
      100,
      ready,
      outerLabel: _outerLabel,
    );
    _emitLog(ready);

    _startWatchdog();
  }

  Future<void> disconnect({bool quiet = false, int? epoch}) async {
    if (epoch == null) {
      _epoch++;
    } else if (_epoch != epoch) {
      return;
    }
    final seen = _epoch;
    _stopFlag = true;
    _watchdog?.cancel();
    _watchdog = null;
    if (_epoch != seen) return;
    await _stopPsiphon();
    await _stopAether();
    if (!quiet) {
      // Explicit user stop: also clear leftovers from crashed sessions so
      // the machine really stops tunneling when the user says stop.
      await _reclaimExitPorts();
    }
    _exitPort = 0;
    _outerLabel = '';
    _exitRegion = '';
    _directPsiphon = false;
    _warpOnly = false;
    _lastOuterProtocol = '';
    _wonTransport = '';
    _wonIp = '';
    _dialing = '';
    if (!quiet) {
      status.reset();
    }
  }

  /// Fires and forgets the helper teardown (used when the app is closing).
  void teardown() {
    unawaited(_stopPsiphon());
    unawaited(_stopAether());
  }

  /// After an app restart the previous session's sidecars can still be
  /// alive and serving the fixed exit ports while this coordinator knows
  /// nothing about them (`_exitPort == 0`). Adopt them when the port probes
  /// healthy so the watchdog can watch the tunnel it did not start; a
  /// listening-but-dead port is left to the next connect's reclaim.
  ///
  /// Adoption never dials anything: when no live tunnel exists the state
  /// stays untouched and `false` comes back, so a plain app start (or a
  /// user profile that is not the Vyrax Free one) cannot start a tunnel
  /// behind the user's back.
  Future<bool> adoptOrphanTunnel() async {
    if (_exitPort != 0 || _stopFlag) return false;
    final psiphonPort = await _adoptProbe(kPowPsiphonSocksPort, true);
    if (psiphonPort) return true;
    return _adoptProbe(kPowChainSocksPort, false);
  }

  /// Test seam: adoption against an arbitrary port instead of the fixed
  /// exit ports. Returns whether [port] was adopted as the exit.
  @visibleForTesting
  Future<bool> adoptOnPort(int port, {required bool chain}) async =>
      _adoptProbe(port, chain);

  Future<bool> _adoptProbe(int port, bool chain) async {
    if (_exitPort != 0 || _stopFlag) return false;
    try {
      if (!await tcpAccepts(port)) return false;
      if (!await probeExitSocks(
        port,
        timeout: const Duration(seconds: 8),
      )) {
        _emitLog(
          'Found a leftover listener on $port that no longer tunnels; '
          'it will be replaced on the next connect',
        );
        return false;
      }
      _exitPort = port;
      _directPsiphon = chain;
      _warpOnly = !chain;
      _outerLabel = chain ? 'Psiphon' : 'WARP';
      _stopFlag = false;
      return true;
    } on Exception catch (error) {
      _emitLog('Tunnel adoption on port $port failed: $error');
      return false;
    }
  }

  void _startWatchdog() {
    final epoch = _epoch;
    _watchdog = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_epoch != epoch || !connected) return;
      if (_warpOnly) {
        if (!_aether.running) {
          _fail('outer leg exited');
        }
      } else {
        if (!_directPsiphon && !_aether.running) {
          _fail('outer leg exited');
        }
        if (!_psiphon.running && connected) {
          _fail('Psiphon exited');
        }
      }
    });
  }

  void _fail(String reason) {
    _watchdog?.cancel();
    _watchdog = null;
    if (_stopFlag) return;
    _emitLog('UAC PoW path lost: $reason');
    _exitPort = 0;
    status.update(PowPhase.failed, 0, reason);
  }

  Future<void> _stopPsiphon() async {
    try {
      await _psiphon.stop();
    } catch (_) {}
  }

  Future<void> _stopAether() async {
    try {
      await _aether.stop();
    } catch (_) {}
  }

  /// A previous app session that exited without cleanup can leave the
  /// tunnel sidecars running. The leftovers keep holding the fixed exit
  /// ports and silently serve the old country, so a fresh tunnel can
  /// never bind and every strategy times out. Take the ports back.
  Future<void> _reclaimExitPorts() async {
    if (!Platform.isWindows) return;
    for (final port in const [kPowChainSocksPort, kPowPsiphonSocksPort]) {
      try {
        final query =
            '(Get-NetTCPConnection -LocalPort $port -State Listen '
            '-ErrorAction SilentlyContinue | Select-Object -First 1 '
            '-ExpandProperty OwningProcess)';
        final listing = await Process.run(
          'powershell',
          ['-NoProfile', '-Command', query],
          runInShell: false,
        );
        final owner = int.tryParse('${listing.stdout}'.trim());
        if (owner == null || owner <= 4 || owner == pid) continue;
        await Process.run(
          'taskkill',
          ['/pid', '$owner', '/T', '/F'],
          runInShell: false,
        );
        _emitLog(
          'Stopped a leftover tunnel process (pid $owner) on port $port',
        );
      } on Exception catch (_) {
        // best effort; the fresh start surfaces real errors
      }
    }
  }

  // ---------------------------------------------------------------- outer

  Future<void> _startNetworkDetect() async {
    final ready = Completer<void>();
    _networkReady = ready;
    try {
      final (key, label) = await detectNetwork();
      _networkKey = key.isEmpty ? 'default' : key;
      _networkLabel = label;
    } on Exception {
      // keep the default key
    } finally {
      ready.complete();
    }
  }

  Future<String> _network() async {
    try {
      await _networkReady?.future.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      // keep default
    }
    if (_networkKey.isEmpty) return 'default';
    return _networkKey;
  }

  List<String> _orderLadder(List<String> ladder) {
    final remembered = store.rememberedOuterProtocol();
    final ordered = List.of(ladder);
    if (remembered != null && ordered.contains(remembered)) {
      ordered.remove(remembered);
      ordered.insert(0, remembered);
    }
    return ordered;
  }

  (List<String>, String) _applyTransportChoice(
    PowSettings settings,
    PowOuterPlan plan,
    List<String> ordered,
  ) {
    final choice = settings.outerTransport.trim().toLowerCase();
    if (choice == outerAuto || !outerLadder.contains(choice)) {
      return (ordered, '');
    }
    final label = outerLabel(choice);
    if (settings.linkRecipe != recipeAuto) {
      final pinned = plan.protocols.map(outerLabel).join(', ');
      _emitLog(
        "Transport $label not used: Link recipe '${settings.linkRecipe}'"
        ' pins $pinned',
      );
      return (ordered, '');
    }
    final rest = ordered.where((item) => item != choice).toList();
    if (rest.isNotEmpty) {
      _emitLog(
        'Transport: $label first (your choice); then '
        '${rest.map(outerLabel).join(', ')} (${plan.summary}) as the fallback',
      );
    } else {
      _emitLog('Transport: $label (your choice)');
    }
    return ([choice, ...rest], choice);
  }

  void _logSpeedOptions(PowSettings settings, bool mci) {
    final on = <String>[];
    if (settings.irancellH3) on.add('HTTP/3 on Irancell');
    if (settings.directPsiphonFirst) on.add('direct Psiphon first');
    if (on.isEmpty) return;
    _emitLog('Speed options on: ${on.join(', ')}');
    if (settings.irancellH3 && mci) {
      _emitLog(
        'HTTP/3 on Irancell: not used; this connect uses the Hamrah Aval plan '
        '(firewall MCI, or Auto, which counts as Hamrah Aval). Staying on HTTP/2',
      );
    }
  }

  Future<String?> _raiseOuterLeg(
    PowSettings settings,
    List<String> ladder,
    List<String> ordered,
    bool mci, {
    String preferred = '',
  }) async {
    for (var offset = 0; offset < ordered.length; offset++) {
      _ensureActive();
      final protocol = ordered[offset];
      final label = outerLabel(protocol);
      final attemptScan = settings.scanMode;
      var budget = outerBudgetMs(protocol, scanMode: attemptScan);
      _dialing = protocol;
      if (mci && protocol == 'wireguard' && offset < ordered.length - 1) {
        budget = budget < _mciWgBudgetMs ? budget : _mciWgBudgetMs;
        _emitLog(
          'WireGuard on Hamrah Aval: UDP WireGuard to Cloudflare is usually '
          'blocked here; trying for ${budget ~/ 1000}s before falling back',
        );
      }
      status.update(
        PowPhase.outer,
        20 + offset * 10,
        'Connecting $label',
        outerLabel: label,
      );
      _emitLog(
        'Outer attempt ${offset + 1}/${ordered.length}: $label '
        '(${budget ~/ 1000}s, $attemptScan)',
      );
      if (protocol == 'masque' && _identityReady()) {
        _emitLog(
          'Key: saved WARP key and MASQUE certificate found; skipping the key request',
        );
      } else {
        status.update(
          PowPhase.outer,
          15 + offset * 10,
          'Getting a WARP key',
          outerLabel: label,
        );
        final error = await _fetchKey(settings, protocol, label);
        if (_stopped()) return null;
        if (error != null) {
          _emitLog('$label could not be prepared: $error');
          if (protocol == 'masque') {
            _emitLog(
              settings.chainPsiphon
                  ? 'Key fetch failed on every route; Psiphon will try to connect on its own'
                  : 'Key fetch failed on every route',
            );
            status.note('Key request failed. Staying on this method.', true);
            return null;
          }
          continue;
        }
        status.update(
          PowPhase.outer,
          20 + offset * 10,
          'Connecting $label',
          outerLabel: label,
        );
      }
      final planNow = outerPlan(settings, mci);
      final h3First = _irancellH3Applies(settings, mci, protocol);
      _emitLog(
        'Connecting $label'
        '${protocol == 'masque' ? " over HTTP/${planNow.masqueTransport == 'h2' ? '2' : '3'}" : ''}'
        ' · IP scan ${planNow.ipFor(protocol)} · $attemptScan'
        '${planNow.fragment && protocol == 'masque' ? ' · split ClientHello' : ''}',
      );
      bool ready;
      if (h3First) {
        ready = await _dialIrancellH3(settings, mci, attemptScan, budget);
      } else {
        final outerJson = chainOuterJson(
          dataDir.path,
          protocol,
          settings,
          scanMode: attemptScan,
          mci: mci,
        );
        _ensureActive();
        if (_epoch != _connectEpoch) {
          throw const PowEngineError('stopped');
        }
        try {
          await _aether.start(
            outerJson: outerJson,
            workingDirectory: dataDir.path,
          );
        } on PowEngineException catch (exc) {
          _emitLog('$label could not start: $exc');
          if (protocol == 'masque') {
            status.note('Scan finished. Staying on this method.', true);
            return null;
          }
          continue;
        }
        ready = await _aether.waitReady(
          kPowChainSocksPort,
          Duration(milliseconds: budget),
          () {
            _stopped();
            return _stopFlag;
          },
        );
      }
      if (ready) {
        store.saveOuterProtocol(protocol);
        _lastOuterProtocol = protocol;
        final planWon = outerPlan(settings, mci);
        _wonTransport = protocol == 'masque'
            ? (_h3Transport.isNotEmpty ? _h3Transport : planWon.masqueTransport)
            : '';
        _wonIp = planWon.ipFor(protocol);
        if (preferred.isNotEmpty && protocol != preferred) {
          final wanted = outerLabel(preferred);
          _emitLog(
            '$wanted did not connect; fell back to $label, '
            'which is carrying the outer leg',
          );
          return '$label ($wanted failed, fell back)';
        }
        _emitLog('$label is carrying the outer leg');
        return label;
      }
      if (_stopped()) return null;
      _emitLog('$label did not come up in ${budget ~/ 1000}s');
      await _stopAether();
      if (protocol == 'masque') {
        status.note('Scan finished. Staying on this method.', true);
        return null;
      }
    }
    return null;
  }

  bool _irancellH3Applies(PowSettings settings, bool mci, String protocol) {
    if (!settings.irancellH3 || mci || protocol != 'masque') return false;
    if (settings.linkRecipe != recipeAuto) {
      _emitLog(
        "HTTP/3 on Irancell: not used; Link recipe '${settings.linkRecipe}' "
        'pins the transport',
      );
      return false;
    }
    return true;
  }

  Future<bool> _dialIrancellH3(
    PowSettings settings,
    bool mci,
    String scanMode,
    int budget,
  ) async {
    final h3Budget = budget < irancellH3BudgetMs ? budget : irancellH3BudgetMs;
    _h3Transport = '';
    for (final (transport, window) in [('h3', h3Budget), ('h2', budget)]) {
      _ensureActive();
      if (transport == 'h3') {
        _emitLog(
          'HTTP/3 on Irancell: trying MASQUE over HTTP/3 for '
          '${window ~/ 1000}s, then HTTP/2',
        );
      }
      final outerJson = chainOuterJson(
        dataDir.path,
        'masque',
        settings,
        scanMode: scanMode,
        mci: mci,
        masqueTransport: transport,
      );
      _ensureActive();
      if (_epoch != _connectEpoch) {
        throw const PowEngineError('stopped');
      }
      try {
        await _aether.start(
          outerJson: outerJson,
          workingDirectory: dataDir.path,
        );
      } on PowEngineException catch (exc) {
        _emitLog(
          "MASQUE over HTTP/${transport == 'h3' ? '3' : '2'} could not start: $exc",
        );
        continue;
      }
      if (await _aether.waitReady(
        kPowChainSocksPort,
        Duration(milliseconds: window),
        () {
          _stopped();
          return _stopFlag;
        },
      )) {
        _h3Transport = transport;
        _emitLog(
          transport == 'h3'
              ? 'HTTP/3 on Irancell: HTTP/3 won'
              : 'HTTP/3 on Irancell: HTTP/2 fallback won',
        );
        return true;
      }
      if (_stopped()) return false;
      await _stopAether();
      if (transport == 'h3') {
        _emitLog(
          'HTTP/3 on Irancell: HTTP/3 did not come up in ${window ~/ 1000}s; '
          'falling back to MASQUE over HTTP/2',
        );
      }
    }
    return false;
  }

  // ------------------------------------------------------------------ key

  static const _keyRouteNames = {
    keyEch: 'ECH',
    keyFragment: 'split ClientHello',
    keyExternal: 'current network',
  };

  Future<String?> _fetchKey(
    PowSettings settings,
    String protocol,
    String label,
  ) async {
    final mode = settings.keyFetch.isEmpty ? keyAuto : settings.keyFetch;
    final attempts = <(String, int)>[(mode, keyFetchTimeoutS)];
    if (mode == keyAuto) {
      attempts.add((keyFetchFallback, keyFetchRetryTimeoutS));
    }
    var lastError = 'no attempt ran';
    for (var index = 0; index < attempts.length; index++) {
      final (camo, timeout) = attempts[index];
      if (_stopped()) return 'stopped';
      final how = camo == keyAuto
          ? 'racing ECH, split ClientHello and the current network; '
              'first ready route wins'
          : (_keyRouteNames[camo] ?? camo);
      final prefix = index == 0 ? 'Key fetch' : 'Key fetch retry';
      _emitLog('$prefix for $label: $how (up to ${timeout}s)');
      _keyRoute = '';
      final started = DateTime.now();
      try {
        await prepareIdentity(
          binDirectory: binaryDirectory,
          dataDirectory: dataDir.path,
          settings: settings,
          protocol: protocol,
          onLog: _onNativeLog,
          cancelled: () {
            _stopped();
            return _stopFlag;
          },
          timeout: Duration(seconds: timeout),
          apiCamo: camo,
        );
      } on Exception catch (exc) {
        if (_stopFlag) {
          _emitLog('Key fetch cancelled');
          return 'stopped';
        }
        lastError = '$exc';
        _emitLog(
          '$prefix failed after '
          '${DateTime.now().difference(started).inSeconds}s: $lastError',
        );
        continue;
      }
      final routeRaw = _keyRoute.isNotEmpty ? _keyRoute : camo;
      final route =
          camo == keyAuto && _keyRoute.isEmpty ? 'the race' : routeRaw;
      _emitLog(
        'Key fetch done in '
        '${DateTime.now().difference(started).inSeconds}s via $route',
      );
      if (protocol == 'masque') {
        if (_identityReady()) {
          _emitLog('Cert: MASQUE certificate saved with the key');
        } else {
          _emitLog('Cert: the key was saved but no MASQUE certificate came back');
        }
      }
      return null;
    }
    return lastError;
  }

  bool _identityReady() {
    final file = File(identityPath(dataDir.path));
    String text;
    try {
      text = file.readAsStringSync();
    } on FileSystemException {
      return false;
    }
    return text.contains('device_id') && text.contains('BEGIN CERTIFICATE');
  }

  // --------------------------------------------------------------- psiphon

  (List<PowStrategy>, int, String) _strategyOrder(
    bool direct,
    String network,
  ) {
    final ladder = strategyLadderFor(direct);
    final shape = strategySignature(direct);
    int? remembered;
    var start = 0;
    String reason;
    try {
      final keys = ladder.map((s) => rttKey(direct, s.name)).toList();
      remembered = store.networkStrategyIndex(network, shape, ladder.length);
      if (remembered == null && network == 'default') {
        try {
          remembered = store.rememberedStrategyIndex(ladder.length, shape);
        } on Exception {
          remembered = null;
        }
      }
      final saved = store.strategyRtts(network, keys);
      final rttsByName = <String, int>{
        for (final strategy in ladder)
          if (saved.containsKey(rttKey(direct, strategy.name)))
            strategy.name: saved[rttKey(direct, strategy.name)]!,
      };
      start = startIndexOf(ladder, remembered, rttsByName) ?? 0;
      if (rttsByName.length >= 2) {
        reason =
            'lower RTT ${rttsByName.entries.map((e) => '${e.key} ${e.value}ms').join(', ')}';
      } else if (remembered != null) {
        reason = 'remembered for this network';
      } else {
        reason = 'default';
      }
    } on Exception {
      reason = 'default';
    }
    return (ladder, start, reason);
  }

  Future<void> _startPsiphonTunnel(PowSettings settings) async {
    final direct = _directPsiphon;
    final innerDir = path.join(dataDir.path, 'uac-pow-inner');
    await Directory(innerDir).create(recursive: true);
    final network = await _network();
    if (_networkLabel.isNotEmpty) {
      _emitLog('Network: $_networkLabel (memory key $network)');
    }
    final (ladder, start, reason) = _strategyOrder(direct, network);
    final ordered = [
      ...ladder.sublist(start),
      ...ladder.sublist(0, start),
    ];
    final shape = strategySignature(direct);
    _emitLog(
      'Psiphon strategy order (${direct ? 'direct' : 'behind WARP'}): '
      '${ladder.map((s) => '${s.name} ${s.label} ${s.timeoutSeconds}s').join(' -> ')}'
      '; starting at ${ordered[0].name} ($reason)',
    );

    final explicit = egressRegion(settings.exitCountryCode);
    String? biasRegion;
    if (explicit == null && !direct) {
      try {
        biasRegion = autoBiasRegion(
          store.rememberedRegion(network),
          store.availableRegions(),
        );
      } on Exception {
        biasRegion = null;
      }
    }
    if (explicit != null) {
      _emitLog('Psiphon region: user choice ${regionName(explicit)} ($explicit)');
    } else if (biasRegion != null) {
      var isRemembered = false;
      try {
        isRemembered = store.rememberedRegion(network) == biasRegion;
      } on Exception {
        isRemembered = false;
      }
      _emitLog(
        'Psiphon region: Automatic -> nearby ${regionName(biasRegion)} '
        '($biasRegion${isRemembered ? ', remembered' : ''}) for '
        '${nearbyPhaseTimeoutSeconds}s, then any country',
      );
    } else {
      _emitLog('Psiphon region: any country');
    }

    final attempts = <(PowStrategy, String, bool, int)>[];
    if (explicit != null) {
      attempts.add((ordered[0], explicit, false, regionPhaseTimeoutSeconds));
    } else if (biasRegion != null) {
      attempts.add(
        (
          ordered[0],
          biasRegion,
          true,
          nearbyPhaseTimeoutSeconds + 3,
        ),
      );
    }
    for (final strategy in ordered) {
      attempts.add((strategy, '', false, strategy.timeoutSeconds));
    }

    for (final (strategy, preferredRegion, bias, timeout) in attempts) {
      _ensureActive();
      _emitLog(
        'Psiphon strategy ${strategy.name} (${strategy.label})'
        '${preferredRegion.isNotEmpty ? ' region=$preferredRegion' : ''}'
        '${bias ? ' (nearby, ${nearbyPhaseTimeoutSeconds}s then any)' : ''}',
      );
      final configJson = psiphonConfig(
        socksPort: kPowPsiphonSocksPort,
        dataDirectory: innerDir,
        preferredRegion: preferredRegion.isNotEmpty ? preferredRegion : null,
        strategy: strategy,
        optimizedMode: settings.optimizedMode,
        direct: direct,
        regionBias: bias,
        upstreamPort: kPowChainSocksPort,
      );
      try {
        await _psiphon.start(
          configJson: configJson,
          dataDirectory: dataDir.path,
          meekOnly: direct &&
              strategy.preferredProtocols.isNotEmpty &&
              strategy.preferredProtocols
                  .every((protocol) => protocol.startsWith('FRONTED-')),
        );
      } on Exception catch (exc) {
        _emitLog('Psiphon strategy ${strategy.name} could not start: $exc');
        continue;
      }
      if (await _psiphon.waitConnected(
        Duration(seconds: timeout),
        () {
          _stopped();
          return _stopFlag;
        },
      )) {
        final index = ladder.indexWhere((s) => s.name == strategy.name);
        try {
          store.saveNetworkStrategy(network, shape, index);
        } on Exception {
          // memory is best-effort
        }
        try {
          final regions = _psiphon.availableRegions;
          if (regions.isNotEmpty) {
            store.rememberAvailableRegions(regions);
          }
        } on Exception {
          // memory is best-effort
        }
        _exitRegion = _psiphon.serverRegion;
        _emitLog(
          'Psiphon connected via ${strategy.name}'
          '${_exitRegion.isNotEmpty ? ' region=$_exitRegion' : ''}',
        );
        if (bias && preferredRegion.isNotEmpty) {
          _emitLog(
            'Connected in nearby country '
            '${regionName(preferredRegion)} ($preferredRegion)',
          );
        }
        unawaited(
          _afterPsiphonMemory(
            network,
            strategy.name,
            direct,
            rememberRegion: explicit == null && !direct,
          ),
        );
        return;
      }
      await _stopPsiphon();
      if (preferredRegion.isNotEmpty) {
        _emitLog(
          '${bias ? 'Nearby country' : 'Preferred country'} '
          '${regionName(preferredRegion)} ($preferredRegion) did not connect '
          'in ${timeout}s; trying any country',
        );
      } else {
        _emitLog(
          'Psiphon strategy ${strategy.name} did not connect in ${timeout}s',
        );
      }
    }
    status.update(PowPhase.failed, 0, 'Psiphon did not connect in time');
    throw const PowEngineError('Psiphon did not connect in time');
  }

  Future<bool> _tryDirectPsiphonFast(PowSettings settings) async {
    if (!settings.chainPsiphon) {
      _emitLog('Direct Psiphon first: skipped; Psiphon chain is off (WARP only)');
      return false;
    }
    _ensureActive();
    try {
      await _networkReady?.future
          .timeout(const Duration(seconds: 1));
    } on TimeoutException {
      // fall back to the default network key
    }
    final network = _networkKey.isEmpty ? 'default' : _networkKey;
    final (ladder, start, _) = _strategyOrder(true, network);
    final strategy = PowStrategy(
      ladder[start].name,
      ladder[start].label,
      directFastBudgetS,
      ladder[start].preferredProtocols,
    );
    final innerDir = path.join(dataDir.path, 'uac-pow-inner');
    await Directory(innerDir).create(recursive: true);
    status.update(PowPhase.inner, 10, 'Trying Psiphon directly (fast mode)');
    _emitLog(
      'Direct Psiphon first: trying Psiphon without WARP for '
      '${directFastBudgetS}s via ${strategy.name} (${strategy.label})',
    );
    final configJson = psiphonConfig(
      socksPort: kPowPsiphonSocksPort,
      dataDirectory: innerDir,
      preferredRegion: egressRegion(settings.exitCountryCode),
      strategy: strategy,
      optimizedMode: settings.optimizedMode,
      direct: true,
    );
    final started = DateTime.now();
    try {
      await _psiphon.start(
        configJson: configJson,
        dataDirectory: dataDir.path,
        meekOnly: strategy.preferredProtocols.isNotEmpty &&
            strategy.preferredProtocols
                .every((protocol) => protocol.startsWith('FRONTED-')),
      );
    } on Exception catch (exc) {
      _emitLog(
        'Direct Psiphon first: could not start ($exc); '
        'continuing with WARP + Psiphon',
      );
      return false;
    }
    if (await _psiphon.waitConnected(
      const Duration(seconds: directFastBudgetS),
      () {
        _stopped();
        return _stopFlag;
      },
    )) {
      _directPsiphon = true;
      _exitRegion = _psiphon.serverRegion;
      _emitLog(
        'Direct Psiphon first: direct Psiphon won in '
        '${DateTime.now().difference(started).inMilliseconds / 1000.0}s '
        'via ${strategy.name}; WARP skipped',
      );
      unawaited(
        _afterPsiphonMemory(network, strategy.name, true, rememberRegion: false),
      );
      return true;
    }
    await _stopPsiphon();
    if (!_stopFlag) {
      _emitLog(
        'Direct Psiphon first: no direct connect in ${directFastBudgetS}s; '
        'continuing with WARP + Psiphon',
      );
    }
    return false;
  }

  Future<void> _afterPsiphonMemory(
    String network,
    String strategyName,
    bool direct, {
    required bool rememberRegion,
  }) async {
    final epoch = _epoch;
    final deadline = DateTime.now().add(const Duration(seconds: 6));
    while (_psiphon.serverRegion.isEmpty &&
        DateTime.now().isBefore(deadline)) {
      if (_stopFlag || _epoch != epoch) return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    final code = _psiphon.serverRegion.trim().toUpperCase();
    if (code.isNotEmpty) {
      _exitRegion = code;
      try {
        store.saveLastConnectRegion(code);
      } on Exception {
        // memory is best-effort
      }
    }
    if (rememberRegion && nearby.contains(code)) {
      try {
        if (store.rememberedRegion(network) != code) {
          store.saveRegion(network, code);
          _emitLog(
            'Remembered exit ${regionName(code)} ($code) for this network; '
            'next Automatic connect tries it first',
          );
        }
      } on Exception {
        // memory is best-effort
      }
    }
    for (var i = 0; i < 15; i++) {
      if (_stopFlag || _epoch != epoch) return;
      if (_exitPort != 0 && connected) break;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    final rtt = await _measureTunnelRtt();
    if (rtt <= 0 || _stopFlag || _epoch != epoch) return;
    try {
      store.saveStrategyRtt(network, rttKey(direct, strategyName), rtt);
    } on Exception {
      // memory is best-effort
    }
    _emitLog(
      'Psiphon tunnel RTT $rtt ms via $strategyName; saved for this network',
    );
  }

  Future<int> _measureTunnelRtt() async {
    const name = 'www.gstatic.com';
    final nameBytes = utf8.encode(name);
    const probePort = 443;
    final samples = <int>[];
    for (var sample = 0; sample < _rttpProbeSamples; sample++) {
      if (_stopFlag) break;
      Socket? sock;
      try {
        sock = await Socket.connect(
          '127.0.0.1',
          kPowPsiphonSocksPort,
          timeout: const Duration(seconds: 8),
        );
        sock.add(const [0x05, 0x01, 0x00]);
        final greeting = await _readChunk(sock).timeout(
          const Duration(seconds: 8),
        );
        if (greeting.length < 2 ||
            greeting[0] != 0x05 ||
            greeting[1] != 0x00) {
          continue;
        }
        final stopwatch = Stopwatch()..start();
        sock.add([
          0x05,
          0x01,
          0x00,
          0x03,
          nameBytes.length,
          ...nameBytes,
          (probePort >> 8) & 0xFF,
          probePort & 0xFF,
        ]);
        final reply = await _readChunk(sock).timeout(
          const Duration(seconds: 8),
        );
        if (reply.length >= 2 &&
            reply[1] == 0 &&
            stopwatch.elapsedMilliseconds > 0) {
          samples.add(stopwatch.elapsedMilliseconds);
        }
      } on Exception {
        continue;
      } finally {
        sock?.destroy();
      }
    }
    if (samples.isEmpty) return 0;
    return samples.reduce((a, b) => a < b ? a : b);
  }

  // --------------------------------------------------------------- logging

  void _onNativeLog(String line) {
    final text = line.trim();
    if (text.isEmpty) return;
    if (text.startsWith('Key: probing ') && text.contains('clean key edge')) {
      _cleanAnswered = 0;
      _emitLog(
        'Clean-IP scan for the key/cert request: ${text.substring(5)}',
      );
    } else if (text.startsWith('Key: clean key address ') &&
        text.endsWith(' answered')) {
      _cleanAnswered++;
    } else if (text.startsWith('Key: key request will use ')) {
      final chosen = text.substring(25).trim();
      _emitLog(
        'Clean IP for key/cert: $chosen ($_cleanAnswered clean edges answered)',
      );
    } else if (text.startsWith('Key: clean-edge probe returned nothing')) {
      _emitLog(
        'Clean-IP scan found no edge; the racers fall back to the pinned list',
      );
    } else if (text.startsWith('MASQUE identity refused') ||
        text.startsWith('New MASQUE certificate issued') ||
        text.startsWith('Could not refresh the MASQUE certificate') ||
        text.startsWith('The MASQUE certificate could not be renewed')) {
      _emitLog(
        'Cert loop: ${_capText(text, 280)}',
      );
    }
    if (text.startsWith('Key:') && text.contains('account key won via ')) {
      final route = text
          .split('account key won via ')[1]
          .split(' ')
          .first
          .trim();
      _keyRoute = route;
      _emitLog(
        'Key fetch: ${_keyRouteNames[route] ?? route} won the race; '
        'the other routes were cancelled',
      );
    }
    if ((_dialing == 'wireguard' || _dialing == 'gool') &&
        (text.startsWith('[+]') ||
            text.startsWith('[-]') ||
            text.startsWith('[*]') ||
            text.startsWith('[wg]'))) {
      _emitLog('${outerLabel(_dialing)} core: ${_capText(text, 300)}');
      return;
    }
    final mapped = stageLine(text);
    if (mapped == null) return;
    _emitStepLine(mapped);
  }

  void _emitStepLine(String mapped) {
    _emitLog(_capText(mapped, 300));
    if (mapped.startsWith('Scan ')) {
      final parts = mapped.split(' ');
      status.scan(mapped, parts.length > 2 ? parts.last : 'other');
    } else {
      final failed = mapped.startsWith('Every saved') ||
          mapped.startsWith('Tunnel did not') ||
          mapped.startsWith('UDP/1701 did not') ||
          mapped.startsWith('No usable MASQUE');
      status.note(mapped, failed);
    }
  }

  void _onPsiphonNotice(PsiphonNotice notice) {
    final kind = notice.kind;
    if (kind == 'log') {
      final message = '${notice.data['message'] ?? ''}';
      if (message.isNotEmpty) {
        _emitLog('Psiphon: ${_capText(message, 300)}');
      }
    } else if (kind == 'Diagnostic') {
      final text = _capText(json.encode(notice.data), 300);
      if (text.isNotEmpty && text != '{}') {
        _emitLog('Psiphon diagnostic: $text');
      }
    } else if (kind == 'ConnectedServerRegion') {
      final region = '${notice.data['region'] ?? ''}';
      if (region.isNotEmpty) {
        _exitRegion = region;
        onExitRegion?.call(region);
      }
    }
  }

  String _capText(String text, int limit) =>
      text.length > limit ? text.substring(0, limit) : text;
}
