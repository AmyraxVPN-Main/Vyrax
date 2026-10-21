import 'dart:convert';

import 'package:fl_clash/features/mozilla/api.dart';
import 'package:fl_clash/features/mozilla/catalog.dart';
import 'package:fl_clash/features/mozilla/runtime_config.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> profile() => mozillaProfile([
  {
    'name': 'example',
    'server': 'example.fastly-masque.net',
    'port': 443,
    'x-flclash-mozilla': true,
    'username': 'stale',
    'password': 'stale',
  },
]);

void main() {
  test('runtime authorization never mutates the shareable profile', () {
    final source = profile();
    final before = jsonEncode(source);
    final runtime = resolveMozillaProxies(source, 'synthetic-pass');
    expect(jsonEncode(source), before);
    expect(before, isNot(contains('synthetic-pass')));
    final proxy = (runtime['proxies'] as List).single as Map;
    expect(proxy['headers'], {'Proxy-Authorization': 'Bearer synthetic-pass'});
    expect(proxy['network'], 'h2');
    expect(proxy['tls'], isTrue);
    expect(proxy['skip-cert-verify'], isFalse);
    expect(proxy.containsKey('password'), isFalse);
    expect(proxy.containsKey('username'), isFalse);
  });

  test('marked hostile endpoints cannot receive authorization', () {
    final source = profile();
    source['proxies'][0]['server'] = 'example.fastly-masque.net.attacker.test';
    expect(
      () => resolveMozillaProxies(source, 'synthetic-pass'),
      throwsA(isA<MozillaException>()),
    );
  });

  test(
    'managed profiles reject UDP and retain protected DNS after overrides',
    () {
      final source = profile();
      source['dns'] = {
        'listen': '',
        'nameserver': ['system://'],
        'fallback': ['8.8.8.8'],
      };
      source['rules'] = ['MATCH,PROXY'];
      protectMozillaTraffic(source);
      expect(source['dns']['nameserver'], ['https://1.1.1.1/dns-query#PROXY']);
      expect(source['dns'].containsKey('fallback'), isFalse);
      expect(source['dns']['listen'], '');
      expect(source['rules'].first, 'NETWORK,udp,REJECT');
      final ordinary = {
        'proxies': <dynamic>[],
        'rules': ['MATCH,DIRECT'],
      };
      expect(resolveMozillaProxies(ordinary, 'unused'), same(ordinary));
      protectMozillaTraffic(ordinary);
      expect(ordinary['rules'], ['MATCH,DIRECT']);
    },
  );
}
