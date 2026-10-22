import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/yaml_writer.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'engine.dart';
import 'models.dart';
import 'store.dart';
import 'xray_config.dart';

class SpoofImportResult {
  final String bundleId;
  final int imported;
  final List<String> failures;

  bool get ok => imported > 0;

  const SpoofImportResult({
    required this.bundleId,
    required this.imported,
    required this.failures,
  });
}

class SpoofController extends ChangeNotifier {
  SpoofController(this.ref) {
    _engine = SpoofEngine(() async => Directory(await appPath.homeDirPath));
    _engine.state.addListener(_notify);
    unawaited(
      globalState.safeRun(() async {
        final store = ref.read(spoofStoreProvider);
        final settings = await store.loadSettings();
        carrier = settings.carrier;
        fragment = settings.fragment;
        iranDirect = settings.iranDirect;
        muxDefault = settings.mux;
        activeId = settings.activeId;
        bundles = await store.loadBundles();
        if (activeId != null && bundleById(activeId!) == null) {
          activeId = null;
        }
        _notify();
      }),
    );
  }

  final Ref ref;
  late final SpoofEngine _engine;
  List<SpoofBundle> bundles = [];
  String? activeId;
  SpoofCarrier carrier = SpoofCarrier.auto;
  String fragment = 'full5';
  bool iranDirect = true;
  bool muxDefault = false;
  bool busy = false;
  double? installProgress;

  SpoofEngineState get engineState => _engine.state.value;

  ValueListenable<SpoofEngineState> get stateListenable => _engine.state;

  List<String> get logs => List.unmodifiable(_engine.logLines);

  SpoofBundle? get activeBundle => bundleById(activeId ?? '');

  SpoofBundle? bundleById(String id) =>
      bundles.where((bundle) => bundle.id == id).firstOrNull;

  void _notify() => notifyListeners();

  SpoofFragmentSettings _fragmentSettings() {
    if (fragment == 'plain') {
      return const SpoofFragmentSettings();
    }
    final strategy = SpoofFragmentStrategyName.fromName(fragment);
    return SpoofFragmentSettings.forStrategy(strategy);
  }

  Future<void> updateSettings({
    SpoofCarrier? newCarrier,
    String? newFragment,
    bool? newIranDirect,
    bool? newMux,
  }) async {
    carrier = newCarrier ?? carrier;
    fragment = newFragment ?? fragment;
    iranDirect = newIranDirect ?? iranDirect;
    muxDefault = newMux ?? muxDefault;
    await ref.read(spoofStoreProvider).saveSettings(
      carrier: carrier,
      fragment: fragment,
      iranDirect: iranDirect,
      mux: muxDefault,
    );
    _notify();
  }

  Future<SpoofImportResult> importText(String text) async {
    final support = _fragmentSettings();
    final baseCarrier = carrier == SpoofCarrier.mci ? 'MCI' : '';
    final servers = <SpoofProfile>[];
    final failures = <String>[];
    for (final raw in text.split(RegExp(r'\s+'))) {
      final line = raw.trim();
      if (line.isEmpty ||
          !(line.startsWith('vless://') ||
              line.startsWith('trojan://') ||
              line.startsWith('vmess://'))) {
        continue;
      }
      try {
        var profile = parseSpoofShareLink(line, countryCode: baseCarrier);
        if (!profile.isReality && support.hasFragment) {
          profile = profile.copyWith(fragment: support);
        }
        if (carrier == SpoofCarrier.mci && profile.edge.isEmpty) {
          profile = profile.copyWith(edge: kMciPrimaryEdge);
        }
        servers.add(profile);
      } on FormatException {
        failures.add(line);
      } on SpoofShareLinkException {
        failures.add(line);
      } catch (_) {
        failures.add(line);
      }
    }
    if (servers.isEmpty) {
      return SpoofImportResult(
        bundleId: '',
        imported: 0,
        failures: failures,
      );
    }
    final bundle = SpoofBundle(
      id: 'spoof-bundle-${DateTime.now().millisecondsSinceEpoch}',
      servers: servers,
      createdAt: DateTime.now(),
    );
    bundles = [bundle, ...bundles];
    await ref.read(spoofStoreProvider).saveBundles(bundles);
    _notify();
    return SpoofImportResult(
      bundleId: bundle.id,
      imported: servers.length,
      failures: failures,
    );
  }

  Future<void> remove(String id) async {
    if (activeId == id) {
      await disconnect();
    }
    bundles = [...bundles.where((bundle) => bundle.id != id)];
    if (activeId == id) {
      activeId = null;
      await ref.read(spoofStoreProvider).saveSettings(activeId: null);
    }
    await ref.read(spoofStoreProvider).saveBundles(bundles);
    _notify();
  }

  Future<void> connect(String id) async {
    if (busy) return;
    final bundle = bundleById(id);
    if (bundle == null) return;
    busy = true;
    _notify();
    try {
      if (!await _engine.isInstalled()) {
        await globalState.safeRun(
          () => _engine.install(
            onProgress: (progress) {
              installProgress = progress.clamp(0.0, 1.0);
              _notify();
            },
          ),
          title: 'spoof-install',
        );
        if (!await _engine.isInstalled()) {
          throw const XrayProvisionException('install');
        }
      }
      if (_engine.isRunning) {
        await _engine.stopAll();
      }
      final fragmentSettings = _fragmentSettings();
      var index = 0;
      for (final server in bundle.servers) {
        try {
          await _engine.startServer(
            _serverKey(id, index),
            server.isReality
                ? server.copyWith(
                    fragment: const SpoofFragmentSettings(),
                  )
                : server.copyWith(fragment: fragmentSettings),
            iranDirect: iranDirect,
          );
        } catch (error) {
          await _engine.stopAll();
          rethrow;
        }
        index++;
      }
      final probe = await _probe();
      final traced = await _trace();
      activeId = id;
      await ref.read(spoofStoreProvider).saveSettings(activeId: id);
      _engine.state.value = _engine.state.value.copyWith(
        probeMs: probe.elapsedMs,
        exitCountry: traced.$1.isEmpty ? null : traced.$1,
        exitIp: traced.$2.isEmpty ? null : traced.$2,
        clearFailure: true,
      );
      await _applyVyraxProfile(bundle);
    } on XrayProvisionException catch (error) {
      _engine.state.value = _engine.state.value.copyWith(
        failure: error.reason,
      );
    } catch (error) {
      _engine.state.value = _engine.state.value.copyWith(
        failure: error.toString(),
      );
    } finally {
      busy = false;
      installProgress = null;
      _notify();
    }
  }

  Future<void> disconnect() async {
    if (busy) return;
    busy = true;
    _notify();
    try {
      await _engine.stopAll();
      if (_isWithSpoofProfile()) {
        await ref.read(setupActionProvider.notifier).setRunning(false);
      }
      activeId = null;
      await ref.read(spoofStoreProvider).saveSettings(activeId: null);
    } finally {
      busy = false;
      _notify();
    }
  }

  bool _isWithSpoofProfile() =>
      ref.read(currentProfileIdProvider) == kSpoofSystemProfileId;

  String _serverKey(String bundleId, int index) {
    final safe =
        bundleId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '').substring(0, 18);
    return '$safe-$index';
  }

  HttpClient _probeClient(int httpPort) {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    client.findProxy = (uri) => 'PROXY 127.0.0.1:$httpPort';
    return client;
  }

  (int, int) _primaryPorts() {
    final key = _engine.sessionKeys.isEmpty ? '' : _engine.sessionKeys.first;
    return _engine.portsOf(key);
  }

  Future<SpoofProbeResult> _probe({
    String host = 'https://www.gstatic.com/generate_204',
  }) async {
    final (socksPort, _) = _primaryPorts();
    if (socksPort == 0) {
      return const SpoofProbeResult(ok: false, elapsedMs: 0);
    }
    final client = _probeClient(socksPort);
    final stopwatch = Stopwatch()..start();
    try {
      final response = await client
          .getUrl(Uri.parse(host))
          .then((request) => request.close())
          .timeout(const Duration(seconds: 8));
      await response.drain();
      return SpoofProbeResult(
        ok: response.statusCode >= 200 && response.statusCode < 500,
        elapsedMs: stopwatch.elapsedMilliseconds,
      );
    } catch (_) {
      return SpoofProbeResult(
        ok: false,
        elapsedMs: stopwatch.elapsedMilliseconds,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<(String, String)> _trace() async {
    final (_, httpPort) = _primaryPorts();
    if (httpPort == 0) return ('', '');
    final client = _probeClient(httpPort);
    try {
      final response = await client
          .getUrl(Uri.https('www.cloudflare.com', '/cdn-cgi/trace'))
          .then((request) => request.close())
          .timeout(const Duration(seconds: 6));
      final body = await utf8.decodeStream(response);
      String country = '';
      String ip = '';
      for (final line in body.split('\n')) {
        if (line.startsWith('loc=')) {
          country = line.substring(4).trim();
        } else if (line.startsWith('ip=')) {
          ip = line.substring(3).trim();
        }
      }
      return (country, ip);
    } catch (_) {
      return ('', '');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _applyVyraxProfile(SpoofBundle bundle) async {
    final proxies = <Map<String, dynamic>>[];
    final proxyNames = <String>[];
    final usedNames = <String>{};
    var index = 0;
    for (final server in bundle.servers) {
      final (socksPort, _) = _engine.portsOf(_serverKey(bundle.id, index));
      if (socksPort == 0) {
        index++;
        continue;
      }
      var name = 'Spoof · ${server.displayLabel}';
      var suffix = index + 1;
      while (usedNames.contains(name)) {
        name = 'Spoof · ${server.displayLabel} ${++suffix}';
      }
      usedNames.add(name);
      proxies.add({
        'name': name,
        'type': 'socks5',
        'server': '127.0.0.1',
        'port': socksPort,
        'udp': true,
      });
      proxyNames.add(name);
      index++;
    }
    if (proxies.isEmpty) {
      throw const XrayProvisionException('no-servers');
    }
    final strorProvider = ref.read(profilesProvider);
    final existing = strorProvider
        .where((candidate) => candidate.id == kSpoofSystemProfileId)
        .firstOrNull;
    final newProfile =
        existing ??
        Profile.normal(label: 'Vyrax Spoof').copyWith(
          id: kSpoofSystemProfileId,
          order: -2,
        );
    final core = ref.read(coreHandlerProvider);
    final saved = await newProfile
        .copyWith(autoUpdate: false)
        .saveFile(
          Uint8List.fromList(
            utf8.encode(
              writeYaml({
                'proxies': proxies,
                'proxy-groups': [
                  {'name': 'PROXY', 'type': 'select', 'proxies': proxyNames},
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
          validate: (path, _) => core.validateConfig(path),
        );
    ref.read(profilesActionProvider.notifier).setProfileAndAutoApply(saved);
    ref.read(currentProfileIdProvider.notifier).value = saved.id;
  }

  @override
  void dispose() {
    _engine.state.removeListener(_notify);
    unawaited(_engine.stopAll());
    super.dispose();
  }
}

final spoofControllerProvider = Provider<SpoofController>((ref) {
  final controller = SpoofController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});
