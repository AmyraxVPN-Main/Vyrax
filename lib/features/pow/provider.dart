import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/yaml_writer.dart';
import 'package:fl_clash/features/spoof/provider.dart' as spoof;
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import 'coordinator.dart';
import 'engine.dart';
import 'models.dart' as pow_models;
import 'status.dart';
import 'store.dart';

/// Whether pressing the run button with [profileId] active must raise the
/// Vyrax Free tunnel through the connect flow dialog instead of the plain
/// core toggle. As long as the tunnel is down — even while a background
/// recovery is already dialling — the run button opens the flow and the
/// core only starts once the dialog reports a live exit, so the app never
/// runs against a dead exit. Top-level so the decision is covered by unit
/// tests.
bool powRunNeedsConnectFlow({
  required int? profileId,
  required bool hasServerSlot,
  required bool tunnelUp,
  required bool busy,
}) {
  if (profileId != kPowSystemProfileId) return false;
  if (tunnelUp) return false;
  return hasServerSlot;
}

/// Exponential backoff between automatic rescan attempts: [attempt] 1, 2, …
/// doubles [base] each attempt, capped at [cap]. Top-level (instead of a
/// controller method) so the ladder is covered by unit tests.
Duration powBackoffFor(
  int attempt, {
  Duration base = const Duration(minutes: 2),
  Duration cap = const Duration(minutes: 10),
}) {
  // Doubling in a loop (instead of base * 2^n) keeps huge attempt counts
  // from overflowing Duration arithmetic; the cap bounds the wait.
  var delay = base;
  for (var i = 1; i < attempt && delay < cap; i++) {
    delay = delay * 2;
  }
  if (delay > cap || delay < Duration.zero) {
    delay = cap;
  }
  return delay;
}

/// Owns the Vyrax Free (UAC PoW) engine: assets, coordinator, logs and the
/// app-managed "Vyrax Free" mihomo profile pointing at the exit SOCKS.
class PowController extends ChangeNotifier {
  PowController(this.ref) {
    unawaited(
      globalState.safeRun(() async {
        final dir = Directory(await appPath.homeDirPath);
        _store = PowStore(dir);
        settings = _store!.snapshot();
        _coordinator = PowCoordinator(
          dir,
          _store!,
          logger: _onLog,
        );
        _coordinator!.status.addListener(_onStatus);
        _coordinator!.onExitRegion = _onExitRegionNotice;
        _syncActiveServerRegion(notify: false);
        // The multi-server list UI is gone; collapse any leftover slots to
        // the active one so the store keeps a single switcher entry.
        final rows = _store?.servers() ?? const <PowServerRow>[];
        if (rows.length > 1) {
          final activeId = _store!.activeServerId();
          for (final row in rows) {
            if (row.id != activeId) {
              _store!.removeServer(row.id);
            }
          }
        }
        if (_store?.servers().isEmpty ?? false) {
          await _removePowProfile();
        } else {
          await _relabelFromLastConnect();
          // Do not recreate a missing profile during startup.  Selecting an
          // exit country or pressing Connect is an explicit user action; a
          // background restore must never add a profile by itself.
        }
        // Do not install/copy the PoW sidecars while the user is merely
        // opening the Vyrax Free panel.  The first panel click used to do
        // all binary I/O here and caused a visible UI hitch. Connect() owns
        // installation now, immediately before the first real dial.
        unawaited(_reconcileAfterStartup());
        _notify();
      }),
    );
  }

  final Ref ref;

  PowStore? _store;
  PowCoordinator? _coordinator;

  pow_models.PowSettings settings = const pow_models.PowSettings().validated();

  bool busy = false;
  double? installProgress;
  String? failure;
  PowStatus status = const PowStatus();
  final List<String> _logs = [];
  static const _logCap = 200;

  /// Watches the live tunnel: free Psiphon servers quietly go offline after
  /// a while, so a probe through the exit SOCKS catches the death early and
  /// a rescan rebuilds the connection without the user noticing.
  Timer? _watchdog;
  Timer? _retryTimer;
  int _watchdogEpoch = 0;
  int _probeFailures = 0;
  bool _autoRecovering = false;
  bool _manualStop = false;
  /// A connect() in this session reached a live exit at least once, so the
  /// coordinator's process-watchdog "failed" status is a lost tunnel (not a
  /// plain connect failure) and may trigger the automatic recovery.
  bool _sessionHadTunnel = false;
  var _disposed = false;
  PowHealthState _healthState = PowHealthState.disabled;
  DateTime _lastRecoveryAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _recoveryAttempts = 0;
  static const _watchdogInterval = Duration(seconds: 45);
  static const _recoveryCooldown = Duration(minutes: 4);
  static const _maxRecoveryAttempts = 5;
  static const _probeFailuresNeeded = 2;
  static const _retryBase = Duration(minutes: 2);
  static const _retryCap = Duration(minutes: 10);

  /// Current watchdog state, surfaced by the UI and the profile view.
  PowHealthState get healthState => _healthState;

  /// True while an automatic rescan/discovery is running.
  bool get recovering => _autoRecovering;

  /// The Vyrax Free server slot exists (a country was picked at least
  /// once), so the run flow may raise its tunnel.
  bool get hasServerSlot => (_store?.servers().isNotEmpty ?? false);

  List<String> get logs => List.unmodifiable(_logs);

  String get outerLabel => status.outerLabel;

  int get exitPort => _coordinator?.exitPort ?? 0;

  // A bound SOCKS port can exist briefly before the sidecars complete their
  // handshake.  Expose the coordinator's terminal state to the UI so the
  // first render never says Disconnect while the tunnel is only starting.
  bool get connected => _coordinator?.connected ?? false;

  bool get isWindows => Platform.isWindows;

  PowCoordinator? get coordinator => _coordinator;

  void _notify() => notifyListeners();

  void _onLog(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    _logs.add(trimmed);
    if (_logs.length > _logCap) {
      _logs.removeRange(0, _logs.length - _logCap);
    }
    notifyListeners();
  }

  void _onStatus(PowStatus snapshot) {
    status = snapshot;
    notifyListeners();
    if (snapshot.phase != PowPhase.failed || _disposed) return;
    // The coordinator's process watchdog reports the tunnel processes gone
    // (Psiphon exited, outer leg exited). If a tunnel the user established
    // died, recover automatically — unless the user disconnect/removed or
    // an automatic recovery is already running (single scan rule).
    if (_manualStop || _autoRecovering || busy) return;
    if (_healthState == PowHealthState.disabled && !_sessionHadTunnel) {
      return;
    }
    if (_healthState == PowHealthState.failed && _retryTimer != null) {
      // A retry is already scheduled; fold this trigger into it.
      return;
    }
    unawaited(_recoverConnection());
  }

  /// Psiphon reported the server region it actually connected through.
  /// Persist it and make the profile follow the real exit; the requested
  /// country is only a best-effort hint for the Psiphon service.
  void _onExitRegionNotice(String code) {
    final clean = pow_models.normalizeRegion(code);
    if (clean.isEmpty) return;
    _store?.saveLastConnectRegion(clean);
    final matches = ref
        .read(profilesProvider)
        .where((profile) => profile.id == kPowSystemProfileId);
    if (matches.isEmpty) return;
    final expected = pow_models.regionName(clean);
    final current = matches.first.label;
    final expectedLabel =
        '${clean.toUpperCase().countryFlagEmoji} Vyrax Free · $expected';
    if (current == expectedLabel) return;
    unawaited(
      globalState.safeRun(() async {
        try {
          if (connected &&
              ref.read(currentProfileIdProvider) == kPowSystemProfileId) {
            // Re-apply so the loaded core config (and the Proxies node
            // name) follows the real exit; the SOCKS tunnel is untouched.
            await _applyVyraxFreeProfile(pow_models.kPowPsiphonSocksPort);
          } else {
            await _refreshPowProfile();
          }
        } on Exception catch (error) {
          _onLog('could not apply the real exit region: $error');
        }
      }),
    );
  }

  /// Region picker entry point: applies the location and repairs the Vyrax
  /// Free slot/profile whenever either is missing, so picking a country
  /// (even the same one twice) always ends with a visible profile.
  Future<void> setExitRegion(String code) async {
    await updateSettings(settings.copyWith(exitCountryCode: code));
    final store = _store;
    if (store == null) return;
    final hasSlot = store.servers().isNotEmpty;
    final hasProfile = ref
        .read(profilesProvider)
        .any((profile) => profile.id == kPowSystemProfileId);
    if (hasSlot && hasProfile) return;
    if (!hasSlot) {
      // One slot at most from this path: re-picking a country never
      // duplicates the server row.
      store.addServer(code);
    }
    await _refreshPowProfile();
    _notify();
  }

  Future<void> updateSettings(pow_models.PowSettings newSettings) async {
    final previousRegion = settings.exitCountryCode;
    settings = _store?.save(newSettings.validated()) ??
        newSettings.validated();
    final active = _store?.activeServer();
    if (active != null && active.region != settings.exitCountryCode) {
      await setServerRegion(active.id, settings.exitCountryCode);
    }
    if (settings.exitCountryCode != previousRegion) {
      await _refreshPowProfile();
      // Switching the exit location while connected moves the tunnel:
      // rebuild it with the new region like a plain disconnect + connect.
      if (connected && !busy) {
        unawaited(_switchExitRegion());
      }
    }
    _notify();
  }

  /// Keeps the persisted exit country in step with the active server slot.
  void _syncActiveServerRegion({bool notify = true}) {
    final store = _store;
    if (store == null) return;
    final active = store.activeServer();
    if (active == null || active.region == settings.exitCountryCode) return;
    settings = store
        .save(settings.copyWith(exitCountryCode: active.region).validated())
        .validated();
    if (notify) _notify();
  }

  Future<void> setServerRegion(String id, String region) async {
    _store?.setServerRegion(id, region);
    _syncActiveServerRegion();
    _notify();
  }

  Future<void> _switchExitRegion() async {
    await disconnect();
    await connect();
  }

  Future<void> _removePowProfile() async {
    if (!ref
        .read(profilesProvider)
        .any((profile) => profile.id == kPowSystemProfileId)) {
      return;
    }
    await ref.read(profilesProvider.notifier).del(kPowSystemProfileId);
    await ref
        .read(profilesActionProvider.notifier)
        .clearEffect(kPowSystemProfileId);
    if (ref.read(currentProfileIdProvider) == kPowSystemProfileId) {
      final profiles = ref.read(profilesProvider);
      ref.read(currentProfileIdProvider.notifier).value = profiles.isNotEmpty
          ? profiles.first.id
          : null;
      if (profiles.isEmpty) {
        await ref.read(setupActionProvider.notifier).setRunning(false);
      }
    }
  }

  Future<void> forgetNetworkMemory() async {
    _store?.forgetLearned();
    _notify();
  }

  /// Region the live tunnel actually exits in (empty when unknown).
  String get exitRegion => _coordinator?.exitRegion ?? '';

  /// Full teardown: stops the tunnel, drops the server slots and removes
  /// the generated profile. A later Connect rebuilds everything.
  Future<void> removeVyraxFree() async {
    if (busy && !_autoRecovering) {
      // The connect flow is waiting on sidecars.  A user Stop must cancel
      // that attempt instead of being ignored while busy is true.
      _manualStop = true;
      _stopWatchdog(manual: true);
      try {
        await _coordinator?.disconnect(quiet: true);
      } finally {
        _notify();
      }
      return;
    }
    _stopWatchdog(manual: true);
    busy = true;
    _autoRecovering = false;
    _notify();
    try {
      if (connected) {
        await _coordinator?.disconnect();
      }
      _store?.clearServers();
      await _removePowProfile();
    } finally {
      busy = false;
      _notify();
    }
  }

  /// Bakes the last real exit location into the "Vyrax Free" profile label
  /// so the flag survives restarts without reconnecting.
  Future<void> _relabelFromLastConnect() async {
    // Prefer the region the last tunnel established; fall back to the
    // location the user picked (active server slot) so the label shows the
    // chosen country even before the first connect.
    var region = _store?.readLastConnect().region ?? '';
    if (region.isEmpty) {
      region = settings.exitCountryCode;
    }
    if (region.isEmpty) return;
    final location = pow_models.regionName(region);
    if (location.isEmpty) return;
    if (!ref.read(profilesProvider).any(
          (profile) => profile.id == kPowSystemProfileId,
        )) {
      return;
    }
    final label = '${region.toUpperCase().countryFlagEmoji} '
        'Vyrax Free · $location';
    ref
        .read(profilesProvider.notifier)
        .updateProfile(
          kPowSystemProfileId,
          (profile) => profile.copyWith(label: label),
        );
  }

  Future<bool> _installBinaries() async {
    final dir = Directory(await appPath.homeDirPath);
    final powDir = Directory(path.join(dir.path, 'pow'));
    await globalState.safeRun(
      () => installPowBinaries(
        powDir,
        onProgress: (progress) {
          installProgress = progress.clamp(0.0, 1.0);
          _notify();
        },
      ),
      title: 'pow-install',
    );
    return true;
  }

  /// Stops the spoof engine when it is on (never two engines at once).
  Future<void> _stopSpoofIfActive() async {
    final spoofController = ref.read(spoof.spoofControllerProvider);
    if (spoofController.activeId != null || spoofController.busy) {
      await spoofController.disconnect();
    }
  }

  Future<void> connect() async {
    // A manual Connect always wins over the auto-recovery path, and a second
    // connect request while one is running is ignored (single engine rule).
    if (busy || _autoRecovering || _disposed) return;
    busy = true;
    failure = null;
    _manualStop = false;
    _cancelRetryTimer();
    _notify();
    try {
      if (!isWindows) {
        throw const PowEngineException('windows-only');
      }
      await _stopSpoofIfActive();
      final coordinator = _coordinator;
      if (coordinator == null) {
        throw const PowEngineException('engine-missing');
      }
      await _installBinaries();
      await coordinator.connect(settings);
      if (coordinator.exitPort != 0) {
        // Publish the local Vyrax Free profile as soon as the exit SOCKS is
        // listening. Waiting for Psiphon's region notice here made the
        // profile appear several seconds after Connect was pressed.
        await _applyVyraxFreeProfile(coordinator.exitPort);
        await _awaitExitRegion(coordinator);
        // The late region notice is only for the label/flag; the profile is
        // already usable while that bounded lookup is running.
        await _applyVyraxFreeProfile(coordinator.exitPort);
        _startWatchdog();
      }
    } on PowEngineException catch (error) {
      failure = error.message;
    } on PowEngineError catch (error) {
      if (error.message != 'stopped') {
        failure = error.message;
      }
    } catch (error) {
      failure = error.toString();
    } finally {
      if (_manualStop) {
        // The user hit Disconnect while this connect was still running:
        // make sure the freshly dialled tunnel is torn down too.
        try {
          await _coordinator?.disconnect(quiet: true);
        } on Exception catch (_) {
          // teardown is best effort
        }
      }
      busy = false;
      installProgress = null;
      _notify();
    }
  }

  Future<void> disconnect() async {
    final wasPowActive =
        ref.read(currentProfileIdProvider) == kPowSystemProfileId;
    // A manual Disconnect must be able to cancel an automatic recovery
    // (it stops the tunnel underneath the in-flight connect), so only a
    // plain manual connect run locks the button like this.
    if (busy && !_autoRecovering) {
      // Connect is running in the same controller task.  Mark it cancelled
      // and stop the sidecars now; connect()'s finally block will finish the
      // state transition without allowing a newly opened tunnel to survive.
      _manualStop = true;
      _stopWatchdog(manual: true);
      try {
        await _coordinator?.disconnect(quiet: true);
        await _removePowProfile();
      } finally {
        if (wasPowActive) {
          await ref.read(setupActionProvider.notifier).setRunning(false);
        }
        _notify();
      }
      return;
    }
    busy = true;
    _notify();
    _stopWatchdog(manual: true);
    try {
      await _coordinator?.disconnect();
      // The generated Vyrax Free profile is only valid while its local exit
      // tunnel exists. Remove it on Disconnect so the next session must be
      // started explicitly through Vyrax Free Connect.
      await _removePowProfile();
      if (wasPowActive) {
        await ref.read(setupActionProvider.notifier).setRunning(false);
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  // -------------------------------------------------------------- watchdog

  /// App-restart reconciliation: the Vyrax Free profile survives restarts
  /// while the tunnel sidecars from the previous session may or may not
  /// still be alive. Adopt a still-healthy leftover tunnel (watchdog starts
  /// watching it); otherwise run the rescan once when this profile is the
  /// active one, showing "recovering" instead of a final Failed. A slot
  /// with no active profile only repairs the profile — nothing is dialled
  /// behind the user's back.
  Future<void> _reconcileAfterStartup() async {
    if (_disposed || _manualStop || busy || _autoRecovering) return;
    final store = _store;
    if (store == null || store.servers().isEmpty) return;
    // Startup is reconciliation only. Do not dial or rescan behind the
    // user's back; the first connection attempt belongs to an explicit
    // Play/Connect action.
    _setHealthState(PowHealthState.disabled);
  }


  /// Turns the health watchdog on after a successful connect. Probe
  /// failures back off; manual Disconnect/Remove turns the watchdog off
  /// and never lets it re-dial behind the user's back.
  void _startWatchdog() {
    _cancelRetryTimer();
    _probeFailures = 0;
    _recoveryAttempts = 0;
    _manualStop = false;
    _sessionHadTunnel = true;
    _setHealthState(PowHealthState.healthy);
    _cancelWatchdogTimer();
    final epoch = ++_watchdogEpoch;
    _watchdog = Timer.periodic(_watchdogInterval, (_) {
      unawaited(_watchdogTick(epoch));
    });
  }

  void _cancelWatchdogTimer() {
    _watchdog?.cancel();
    _watchdog = null;
  }

  void _cancelRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// Stops the watchdog. [manual] marks a user-initiated stop (Disconnect or
  /// Remove): from then on nothing in this controller re-dials on its own.
  void _stopWatchdog({bool manual = false}) {
    _cancelWatchdogTimer();
    _cancelRetryTimer();
    if (manual) {
      _manualStop = true;
      _autoRecovering = false;
      _setHealthState(PowHealthState.disabled);
    }
  }

  void _setHealthState(PowHealthState state) {
    if (_disposed) return;
    if (_healthState == state) return;
    _healthState = state;
    _notify();
  }

  /// One watchdog cycle: a real SOCKS5 CONNECT probe through the exit port
  /// (probeExitSocks) — a listening port with a dead upstream reports
  /// failed. A single missing sample is tolerated; consecutive failures
  /// start the automatic recovery.
  Future<void> _watchdogTick(int epoch) async {
    if (_disposed) return;
    if (epoch != _watchdogEpoch) return;
    if (busy || _autoRecovering || _manualStop) return;
    final port = exitPort;
    if (port == 0) return;
    _setHealthState(PowHealthState.checking);
    bool ok;
    try {
      ok = await probeExitSocks(port, timeout: const Duration(seconds: 8));
    } on Exception catch (error) {
      ok = false;
      _onLog('watchdog probe error: $error');
    }
    if (_disposed || _manualStop || epoch != _watchdogEpoch) return;
    if (ok) {
      if (_healthState == PowHealthState.checking) {
        _probeFailures = 0;
        _setHealthState(PowHealthState.healthy);
      }
      return;
    }
    _probeFailures++;
    _onLog(
      'Vyrax Free exit check failed ($_probeFailures/$_probeFailuresNeeded)',
    );
    if (_probeFailures >= _probeFailuresNeeded) {
      unawaited(_recoverConnection());
    } else {
      _setHealthState(PowHealthState.healthy);
    }
  }

  /// Automatic recovery: re-scan Psiphon/WARP and rebuild the tunnel.
  /// Reuses [connect] (no duplicate controller). At most
  /// [_maxRecoveryAttempts] attempts with an exponential backoff between
  /// them ([_retryBase] doubling, capped at [_retryCap]); then the watchdog
  /// stops and a manual Connect is required. A user Disconnect during the
  /// scan cancels everything.
  Future<void> _recoverConnection() async {
    if (_disposed || _autoRecovering || _manualStop || busy) return;
    final since = DateTime.now().difference(_lastRecoveryAt);
    if (since < _recoveryCooldown) {
      if (_retryTimer != null) return;
      _cancelWatchdogTimer();
      _setHealthState(PowHealthState.recovering);
      _retryTimer = Timer(_recoveryCooldown - since, () {
        _retryTimer = null;
        unawaited(_recoverConnection());
      });
      return;
    }
    _autoRecovering = true;
    busy = true;
    failure = null;
    _cancelWatchdogTimer();
    _cancelRetryTimer();
    _setHealthState(PowHealthState.recovering);
    unawaited(
      globalState.safeRun(() async {
        try {
          final coordinator = _coordinator;
          if (coordinator == null) {
            throw const PowEngineException('engine-missing');
          }
          await _installBinaries();
          await coordinator.connect(settings);
          if (_disposed || _manualStop) {
            // The user stopped the tunnel while the rescan was dialling:
            // tear the fresh tunnel down and do not reconnect.
            try {
              await coordinator.disconnect(quiet: true);
            } on Exception catch (_) {
              // teardown is best effort
            }
            return;
          }
          if (coordinator.exitPort == 0) {
            throw const PowEngineException('no exit after rescan');
          }
          await _awaitExitRegion(coordinator);
          await _applyVyraxFreeProfile(coordinator.exitPort);
          _lastRecoveryAt = DateTime.now();
          _recoveryAttempts = 0;
          _probeFailures = 0;
          _startWatchdog();
        } on Exception catch (error) {
          _lastRecoveryAt = DateTime.now();
          _recoveryAttempts++;
          if (_disposed || _manualStop) return;
          final message = switch (error) {
            PowEngineException(:final message) => message,
            PowEngineError(:final message) => message,
            _ => '$error',
          };
          if (message == 'stopped') {
            // Control was handed over (another Connect/Disconnect ran);
            // never schedule a retry behind it.
            return;
          }
          final keep = failure ?? message;
          failure = keep;
          if (_recoveryAttempts >= _maxRecoveryAttempts) {
            _onLog(
              'Vyrax Free recovery gave up after $_maxRecoveryAttempts '
              'attempts; press Connect to try again',
            );
            _setHealthState(PowHealthState.failed);
            return;
          }
          final backoff = _backoffFor(_recoveryAttempts);
          _onLog(
            'Vyrax Free rescan failed ($keep); retrying in '
            '${backoff.inSeconds}s',
          );
          _setHealthState(PowHealthState.failed);
          _retryTimer = Timer(backoff, () {
            _retryTimer = null;
            unawaited(_recoverConnection());
          });
        } finally {
          _autoRecovering = false;
          busy = false;
          installProgress = null;
          _notify();
        }
      }),
    );
  }

  Duration _backoffFor(int attempt) {
    return powBackoffFor(
      attempt,
      base: _retryBase,
      cap: _retryCap,
    );
  }

  /// The Psiphon `ConnectedServerRegion` notice often lands after the
  /// `Tunnels` notice that ends the connect flow, so give it a short
  /// bounded window. The actual region is recorded regardless of the
  /// picked country: Psiphon treats the requested egress as best-effort,
  /// so the real exit (what Network detection shows) must win.
  Future<void> _awaitExitRegion(PowCoordinator coordinator) async {
    if (!settings.chainPsiphon) return;
    const step = Duration(milliseconds: 250);
    final budget = settings.exitCountryCode.isEmpty ? 8000 : 4000;
    for (var waited = 0; waited < budget; waited += 250) {
      if (coordinator.exitRegion.isNotEmpty) break;
      await Future<void>.delayed(step);
    }
    if (coordinator.exitRegion.isNotEmpty) {
      _store?.saveLastConnectRegion(coordinator.exitRegion);
    }
  }

  Future<void> _applyVyraxFreeProfile(int exitPort) async {
    final saved = await _buildPowProfile(
      exitPort,
      actualRegion: coordinator?.exitRegion ?? '',
    );
    ref.read(profilesActionProvider.notifier).setProfileAndAutoApply(saved);
    ref.read(currentProfileIdProvider.notifier).value = saved.id;
  }

  /// Rewrites the "Vyrax Free" profile so a freshly picked location shows
  /// up (label + proxy name + flag) without waiting for the next connect;
  /// recreates the profile outright when it was removed before.
  Future<void> _refreshPowProfile() async {
    final exists = ref
        .read(profilesProvider)
        .any((profile) => profile.id == kPowSystemProfileId);
    if (!exists) {
      try {
        final saved = await _buildPowProfile(pow_models.kPowPsiphonSocksPort);
        ref.read(profilesProvider.notifier).put(saved);
      } on Exception catch (error) {
        _onLog('could not restore the Vyrax Free profile: $error');
      }
      return;
    }
    if (connected) {
      // While the tunnel is live only the label moves — and the real exit
      // wins over the picked country so the UI matches Network detection.
      var region = pow_models.normalizeRegion(
        _coordinator?.exitRegion ?? '',
      );
      if (region.isEmpty) {
        region = settings.exitCountryCode;
      }
      final location = region.isEmpty ? '' : pow_models.regionName(region);
    final flag = region.isEmpty ? '' : region.toUpperCase().countryFlagEmoji;
    final label = location.isEmpty
        ? 'Vyrax Free · Automatic'
        : '$flag Vyrax Free · $location';
      ref.read(profilesProvider.notifier).updateProfile(
            kPowSystemProfileId,
            (profile) => profile.copyWith(label: label),
          );
      return;
    }
    try {
      final saved = await _buildPowProfile(pow_models.kPowPsiphonSocksPort);
      ref.read(profilesProvider.notifier).put(saved);
    } on Exception catch (error) {
      _onLog('could not refresh the Vyrax Free profile: $error');
    }
  }

  Future<Profile> _buildPowProfile(
    int exitPort, {
    String actualRegion = '',
  }) async {
    final profiles = ref.read(profilesProvider);
    // The real tunnel exit wins (it is what Network detection reports);
    // otherwise the user selection; otherwise the last established region
    // (surfaces "Automatic" as a real location).
    var region = pow_models.normalizeRegion(actualRegion);
    if (region.isEmpty) {
      region = settings.exitCountryCode;
    }
    var location = region.isEmpty
        ? ''
        : pow_models.regionName(region);
    if (region.isEmpty) {
      final tunnelRegion = _coordinator?.exitRegion ??
          _store?.readLastConnect().region ??
          '';
      region = tunnelRegion;
      location = region.isEmpty ? '' : pow_models.regionName(region);
    }
    final flag = region.isEmpty ? '' : region.toUpperCase().countryFlagEmoji;
    final label = location.isEmpty
        ? 'Vyrax Free · Automatic'
        : '$flag Vyrax Free · $location';
    final existing = profiles
        .where(
          (profile) => profile.id == kPowSystemProfileId,
        )
        .firstOrNull;
    final newProfile =
        existing ??
        Profile.normal(label: 'Vyrax Free').copyWith(
          id: kPowSystemProfileId,
          order: -3,
        );
    final proxyName = location.isEmpty
        ? 'Free · Automatic'
        : '$flag Free · $location';
    final core = ref.read(coreHandlerProvider);
    return newProfile.copyWith(
      label: label,
      autoUpdate: false,
    ).saveFile(
          Uint8List.fromList(
            utf8.encode(
              writeYaml({
                'proxies': [
                  {
                    'name': proxyName,
                    'type': 'socks5',
                    'server': '127.0.0.1',
                    'port': exitPort,
                    'udp': false,
                  },
                ],
                'proxy-groups': [
                  {
                    'name': 'PROXY',
                    'type': 'select',
                    'proxies': [proxyName],
                  },
                ],
                'dns': {
                  'enable': true,
                  'enhanced-mode': 'fake-ip',
                  'default-nameserver': ['1.1.1.1'],
                  'proxy-server-nameserver': ['https://1.1.1.1/dns-query'],
                  'nameserver': ['https://1.1.1.1/dns-query#PROXY'],
                },
                'rules': ['MATCH,PROXY'],
              }),
            ),
          ),
          // The config is fully app-generated and schema-fixed; a core that
          // is down (or a Psiphon timeout) must never block the profile from
          // being saved and shown. Real validation still runs on connect.
          validate: (path, _) async {
            try {
              return await core.validateConfig(path);
            } catch (error) {
              _onLog(
                'core validation skipped, keeping generated config: $error',
              );
              return '';
            }
          },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _stopWatchdog();
    _coordinator?.status.removeListener(_onStatus);
    _coordinator?.teardown();
    super.dispose();
  }
}

final powControllerProvider = Provider<PowController>((ref) {
  final controller = PowController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});
