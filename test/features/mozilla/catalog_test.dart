import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/features/mozilla/api.dart';
import 'package:fl_clash/features/mozilla/catalog.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> catalog(
  List<Map<String, dynamic>> servers, {
  String name = 'Germany',
}) => {
  'data': [
    {
      'country': {
        'code': 'DE',
        'name': name,
        'cities': [
          {'code': 'BER', 'name': 'Berlin', 'servers': servers},
        ],
      },
    },
  ],
};

void main() {
  test('only official non-quarantined CONNECT edges are accepted', () {
    final servers = parseMozillaServers(
      catalog([
        {'hostname': 'de.example.fastly-masque.net', 'port': 443},
        {'hostname': 'de.example.fastly-masque.net.evil.example', 'port': 443},
        {
          'hostname': 'quarantined.fastly-masque.net',
          'port': 443,
          'quarantined': true,
        },
        {
          'hostname': 'wireguard.fastly-masque.net',
          'port': 443,
          'protocols': [
            {'name': 'wireguard'},
          ],
        },
        {'hostname': 'badport.fastly-masque.net', 'port': 0},
        {'hostname': 'de.example.fastly-masque.net', 'port': 443},
      ]),
    );
    expect(servers, hasLength(1));
    expect(servers.single['network'], 'h2');
    expect(servers.single['skip-cert-verify'], false);
  });
  test('empty official list cannot produce a usable profile', () {
    expect(
      () => parseMozillaServers({'data': []}),
      throwsA(isA<MozillaException>()),
    );
  });
  test('profiles contain no credentials, proxy DNS and reject UDP', () {
    final profile = mozillaProfile(
      parseMozillaServers(
        catalog([
          {'hostname': 'de.example.fastly-masque.net', 'port': 443},
        ]),
      ),
    );
    final serialized = jsonEncode(profile);
    expect(serialized, isNot(contains('Proxy-Authorization')));
    expect(serialized, isNot(contains('accessToken')));
    expect(profile['rules'], ['NETWORK,udp,REJECT', 'MATCH,PROXY']);
    expect((profile['proxy-groups'] as List), hasLength(3));
  });
  test('parses the complete pinned public Mozilla catalog', () {
    final raw =
        jsonDecode(
              File(
                'test/features/mozilla/fixtures/locations.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final proxies = parseMozillaServers(raw);
    expect(proxies.length, greaterThan(20));
    expect(proxies.every((p) => isMozillaEdge(p['server'])), isTrue);
  });
}
