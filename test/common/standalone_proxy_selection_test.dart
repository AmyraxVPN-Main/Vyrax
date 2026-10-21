import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const _nodes = [
  {'name': 'First', 'type': 'http', 'server': '127.0.0.1', 'port': 18080},
  {'name': 'Second', 'type': 'http', 'server': '127.0.0.1', 'port': 18081},
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'already saved nodes-only profile gains a visible selector and route',
    () async {
      final original = <String, dynamic>{
        'proxies': _nodes,
        'proxy-groups': [],
        'rules': [],
      };
      final result = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: '/profiles',
          profileId: 7,
          rawConfig: original,
          realPatchConfig: const PatchClashConfig(),
          appendSystemDns: false,
          proxyGroups: const [],
          rules: const [],
          addedRules: const [],
          defaultUA: 'test',
        ),
      );
      final config = loadYaml(result.yaml) as Map;
      expect(config['proxy-groups'], [
        {
          'name': 'PROXY',
          'type': 'select',
          'proxies': ['Fastest', 'First', 'Second'],
        },
        {
          'name': 'Fastest',
          'type': 'url-test',
          'proxies': ['First', 'Second'],
          'url': defaultTestUrl,
          'interval': 15,
          'timeout': 2000,
          'max-failed-times': 2,
          'lazy': false,
          'selection-interval': 200,
          'tolerance': 0,
          'hidden': true,
        },
      ]);
      expect(config['rules'], ['MATCH,PROXY']);
      expect(config['proxies'], _nodes);
      expect(
        original.containsKey('proxy-groups') &&
            (original['proxy-groups'] as List).isEmpty,
        true,
      );
    },
  );

  test('avoids collisions and remains stable on repeated preparation', () {
    final config = <String, dynamic>{
      'proxies': [
        {'name': 'PROXY'},
        {'name': 'PROXY-1'},
        {'name': 'Fastest'},
        ..._nodes,
      ],
    };
    ensureStandaloneProxySelection(config);
    expect(config['proxy-groups'][0]['name'], 'PROXY-2');
    expect(config['proxy-groups'][0]['proxies'][0], 'Fastest-1');
    expect(config['proxy-groups'][1]['name'], 'Fastest-1');
    expect(config['proxy-groups'][1]['proxies'], [
      'PROXY',
      'PROXY-1',
      'Fastest',
      'First',
      'Second',
    ]);
    expect(config['rules'], ['MATCH,PROXY-2']);
    final groups = config['proxy-groups'];
    ensureStandaloneProxySelection(config);
    expect(identical(config['proxy-groups'], groups), true);
  });

  test('preserves supplied groups and routing policies', () {
    final groups = [
      {
        'name': 'Custom',
        'type': 'select',
        'proxies': ['Second', 'First'],
      },
    ];
    final rules = ['MATCH,Custom'];
    final config = <String, dynamic>{
      'proxies': _nodes,
      'proxy-groups': groups,
      'rules': rules,
    };
    ensureStandaloneProxySelection(config);
    expect(identical(config['proxy-groups'], groups), true);
    expect(identical(config['rules'], rules), true);
    final routed = <String, dynamic>{
      'proxies': _nodes,
      'rules': ['MATCH,DIRECT'],
    };
    ensureStandaloneProxySelection(routed);
    expect(routed['rules'], ['MATCH,DIRECT']);
  });

  test('does not invent a group for an empty profile', () {
    final config = <String, dynamic>{'proxies': []};
    ensureStandaloneProxySelection(config);
    expect(config, {'proxies': []});
  });
}
