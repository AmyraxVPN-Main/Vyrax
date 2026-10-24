import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/features/pow/models.dart' as pow_models;
import 'package:fl_clash/features/pow/status.dart';
import 'package:fl_clash/features/pow/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pow models', () {
    test('validated normalizes fields', () {
      final settings = const pow_models.PowSettings(
        exitCountryCode: ' de ',
        outerTransport: ' MASQUE ',
        obfuscationProfile: 'nope',
        firewallProfile: 'irancell',
        linkRecipe: 'nope',
        keyFetch: 'nope',
        scanMode: 'nope',
      ).validated();
      expect(settings.exitCountryCode, 'de');
      expect(settings.outerTransport, 'masque');
      expect(settings.obfuscationProfile, 'balanced');
      expect(settings.firewallProfile, 'irancell');
      expect(settings.linkRecipe, pow_models.recipeAuto);
      expect(settings.keyFetch, pow_models.defaultKeyFetch);
      expect(settings.scanMode, pow_models.scanBalanced);
    });

    test('outerPlan mci default is masque h2', () {
      final plan = pow_models.outerPlan(
        const pow_models.PowSettings().validated(),
        true,
      );
      expect(plan.protocols, ['masque']);
      expect(plan.masqueTransport, 'h2');
      expect(plan.summary, 'MASQUE HTTP/2');
    });

    test('outerPlan irancell ladder uses h3', () {
      final plan = pow_models.outerPlan(
        const pow_models.PowSettings(firewallProfile: 'irancell').validated(),
        false,
      );
      expect(plan.protocols, const ['masque', 'gool', 'wireguard']);
      expect(plan.masqueTransport, 'h3');
    });

    test('outerPlan recipe pins the protocol', () {
      final plan = pow_models.outerPlan(
        const pow_models.PowSettings(linkRecipe: 'masque-h2').validated(),
        true,
      );
      expect(plan.protocols, ['masque']);
      expect(plan.masqueTransport, 'h2');
      expect(plan.fragment, isFalse);
    });

    test('outerBudget scales with scan mode and retune', () {
      expect(
        pow_models.outerBudgetMs('wireguard', scanMode: 'turbo'),
        16500,
      );
      expect(
        pow_models.outerBudgetMs('gool', scanMode: 'thorough'),
        176000,
      );
      expect(
        pow_models.outerBudgetMs('masque', retune: true),
        55000,
      );
    });

    test('rtt keys and start index order by lowest RTT', () {
      expect(pow_models.rttKey(false, 'A'), 'cA');
      expect(pow_models.rttKey(true, 'F'), 'dF');
      final ladder = pow_models.strategyLadderFor(false);
      expect(
        pow_models.startIndexOf(ladder, null, {'A': 900, 'F': 300}),
        0,
      );
      expect(pow_models.startIndexOf(ladder, 1, {'A': 300}), 1);
    });

    test('strategySignatures differ per direction', () {
      expect(pow_models.strategySignature(false), 'F,A');
      expect(pow_models.strategySignature(true), 'A,F');
    });

    test('autoBiasRegion prefers remembered nearby', () {
      expect(
        pow_models.autoBiasRegion('de', ['NL', 'PL']),
        'NL',
      );
      expect(pow_models.autoBiasRegion('us', ['NL', 'PL']), 'NL');
      expect(pow_models.autoBiasRegion('us', ['US']), null);
      expect(
        pow_models.autoBiasRegion('de', ['US'], rememberedOnly: true),
        null,
      );
    });

    test('region normalize', () {
      expect(pow_models.normalizeRegion(' nl '), 'nl');
      expect(pow_models.normalizeRegion('bad'), '');
      expect(pow_models.egressRegion('bad'), null);
      expect(pow_models.egressRegion('nl'), 'NL');
      expect(
        pow_models.regionName('nl'),
        isNot('nl'),
      );
    });

    test('chainOuterJson payload is singular-string friendly', () {
      final json = jsonDecode(
        pow_models.chainOuterJson(
          r'C:\data',
          'masque',
          const pow_models.PowSettings(linkRecipe: 'masque-h2').validated(),
          mci: true,
        ),
      ) as Map<String, Object?>;
      expect(json['protocol'], 'masque');
      expect(json['masque_transport'], 'h2');
      expect(json['listen'], '127.0.0.1:1820');
      expect(json['obfuscation_profile'], 'balanced');
      expect(json['h2_fragmentation'], isFalse);
      expect(json['ip_scan'], isNotNull);
      expect(json['config_path'], contains('uac-pow.toml'));
    });

    test('psiphonConfig region pin and upstream', () {
      final config = jsonDecode(pow_models.psiphonConfig(
        socksPort: 1821,
        dataDirectory: r'C:\data\inner',
        preferredRegion: 'de',
        strategy: pow_models.strategyA,
        regionBias: true,
      )) as Map<String, Object?>;
      expect(config['EgressRegion'], 'DE');
      expect(config['EstablishTunnelTimeoutSeconds'], 12);
      expect(config['UpstreamProxyURL'], 'socks5://127.0.0.1:1820');
      expect(config['DataDirectory'], r'C:\data\inner');
      expect(config['LocalSocksProxyPort'], 1821);
      expect(
        (config['InitialLimitTunnelProtocols'] as List).first,
        'FRONTED-MEEK-OSSH',
      );
    });

    test('psiphonConfig direct mode has no upstream and meek protocols', () {
      final config = jsonDecode(pow_models.psiphonConfig(
        socksPort: 1821,
        dataDirectory: r'C:\data\inner',
        preferredRegion: null,
        strategy: pow_models.strategyF,
        direct: true,
      )) as Map<String, Object?>;
      expect(config.containsKey('UpstreamProxyURL'), isFalse);
      expect(
        (config['LimitTunnelProtocols'] as List).first,
        'TLS-OSSH',
      );
    });
  });

  group('pow status store', () {
    test('update notes and finishes steps', () {
      final store = PowStatusStore();
      store.update(PowPhase.starting, 5, 'Starting UAC PoW');
      expect(store.snapshot.steps, isNotEmpty);
      store.update(PowPhase.connected, 100, 'UAC PoW ready');
      expect(store.snapshot.phase, PowPhase.connected);
      expect(store.snapshot.steps.last.state, PowStepState.done);
    });

    test('scan replaces the running scan step', () {
      final store = PowStatusStore();
      store.scan('Scan 1.2.3.4 trying', 'trying');
      store.scan('Scan 1.2.3.4 400', '400');
      final steps = store.snapshot.steps;
      expect(steps.length, 1);
      expect(steps.last.text, 'Scan 1.2.3.4 400');
      expect(steps.last.state, PowStepState.failed);
    });

    test('scanPulse maps lines', () {
      expect(
        scanPulse('Scanning 1.2.3.4 via http/2'),
        'Scan 1.2.3.4 trying',
      );
      expect(
        scanPulse('Rejected 1.2.3.4: status 403'),
        'Scan 1.2.3.4 other',
      );
      expect(scanPulse('nothing here'), isNull);
    });

    test('stageLine maps key/cert and masque lines', () {
      expect(stageLine('Key: foo'), 'Key foo');
      expect(stageLine('Cert: bar'), 'Cert bar');
      expect(stageLine('MASQUE start x'), 'MASQUE start x');
      expect(stageLine('MASQUE ambiguity'), isNull);
    });
  });

  group('pow store', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('pow-store');
    });
    tearDown(() {
      dir.deleteSync(recursive: true);
    });

    test('defaults and save round trip', () {
      final path = '${dir.path}${Platform.pathSeparator}pow_settings.json';
      final store = PowStore(dir);
      var settings = store.snapshot();
      expect(settings.outerTransport, 'auto');
      expect(settings.chainPsiphon, isTrue);
      settings = settings
          .copyWith(
            exitCountryCode: 'de',
            outerTransport: 'gool',
            scanMode: 'thorough',
            chainPsiphon: false,
          )
          .validated();
      store.save(settings);
      expect(File(path).existsSync(), isTrue);
      final reloaded = PowStore(dir);
      expect(reloaded.snapshot().exitCountryCode, 'de');
      expect(reloaded.snapshot().outerTransport, 'gool');
      expect(reloaded.snapshot().chainPsiphon, isFalse);
    });

    test('migrates legacy ech key fetch', () {
      File('${dir.path}${Platform.pathSeparator}pow_settings.json')
          .writeAsStringSync(
        jsonEncode({
          'key_fetch': 'ech',
          'exit_country': 'nl',
          'settings_version': 1,
        }),
      );
      final store = PowStore(dir);
      expect(store.snapshot().keyFetch, 'auto');
      expect(store.snapshot().exitCountryCode, 'nl');
    });

    test('network memory routes', () {
      final store = PowStore(dir);
      expect(store.networkStrategyIndex('default', 'A,F', 2), isNull);
      store.saveNetworkStrategy('default', 'A,F', 1);
      store.saveStrategyRtt('default', 'dA', 312);
      store.saveStrategyRtt('default', 'cF', 208);
      store.saveRegion('default', 'NL');
      store.rememberAvailableRegions(['DE', 'nl']);
      expect(store.networkStrategyIndex('default', 'A,F', 2), 1);
      expect(
        store.strategyRtts('default', ['dA', 'cF']),
        {'dA': 312, 'cF': 208},
      );
      expect(store.rememberedRegion('default'), 'NL');
      expect(store.availableRegions(), ['DE', 'NL']);
      store.saveOuterProtocol('masque');
      expect(store.rememberedOuterProtocol(), 'masque');
      store.forgetLearned();
      expect(store.rememberedRegion('default'), isNull);
      expect(store.rememberedOuterProtocol(), 'masque');
      store.saveLastConnect(
        const PowLastConnect(protocol: 'psiphon', transport: 'h3'),
      );
      expect(store.readLastConnect().protocol, 'psiphon');
      expect(store.readLastConnect().transport, 'h3');
    });

    test('servers default to a single slot keeping the exit country', () {
      File('${dir.path}${Platform.pathSeparator}pow_settings.json')
          .writeAsStringSync(
        jsonEncode({'exit_country': 'de', 'settings_version': 2}),
      );
      final store = PowStore(dir);
      final servers = store.servers();
      expect(servers.length, 1);
      expect(servers.first.id, 's1');
      expect(servers.first.region, 'de');
      expect(store.activeServerId(), 's1');
      expect(store.activeServer()?.region, 'de');
    });

    test('servers add select edit remove round trip', () {
      final store = PowStore(dir);
      expect(store.servers().length, 1);
      store.addServer('de');
      var servers = store.servers();
      expect(servers.length, 2);
      expect(servers[1].id, 's2');
      expect(store.activeServerId(), 's2');
      expect(store.activeServer()?.region, 'de');
      store.selectServer('s1');
      expect(store.activeServer()?.region, '');
      store.removeServer('s2');
      servers = store.servers();
      expect(servers.length, 1);
      expect(store.activeServerId(), 's1');
      store.removeServer('s1');
      expect(store.servers(), isEmpty);
      expect(store.activeServerId(), '');
    });
  });
}
