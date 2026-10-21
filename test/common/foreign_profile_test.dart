import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_clash/common/foreign_profile.dart';
import 'package:flutter_test/flutter_test.dart';

const uuid = '00000000-0000-4000-8000-000000000001';
Map<String, dynamic> converted(dynamic value) =>
    jsonDecode(
          utf8.decode(
            convertForeignProfile(
              Uint8List.fromList(utf8.encode(jsonEncode(value))),
            ),
          ),
        )
        as Map<String, dynamic>;

Map<String, dynamic> sing([String type = 'vless']) => {
  'type': type,
  'tag': 'edge',
  'server': 'example.com',
  'server_port': 443,
  if (type == 'trojan' || type == 'tuic' || type == 'hysteria2')
    'tls': {'enabled': true, 'server_name': 'example.com'},
  if (type == 'vless' || type == 'vmess' || type == 'tuic') 'uuid': uuid,
  if (type == 'trojan' ||
      type == 'shadowsocks' ||
      type == 'hysteria2' ||
      type == 'tuic')
    'password': 'fixture-password',
  if (type == 'shadowsocks') 'method': 'aes-128-gcm',
};

Map<String, dynamic> xray() => {
  'protocol': 'vless',
  'tag': 'edge',
  'settings': {
    'vnext': [
      {
        'address': 'example.com',
        'port': 443,
        'users': [
          {'id': uuid, 'encryption': 'none'},
        ],
      },
    ],
  },
};

void main() {
  test('Base64 YAML subscriptions reach native validation decoded', () {
    const yaml = 'proxies:\n  - name: Edge\n    type: direct\n';
    final encoded = base64Url.encode(utf8.encode(yaml));
    expect(
      utf8.decode(
        convertForeignProfile(Uint8List.fromList(utf8.encode(encoded))),
      ),
      yaml,
    );
  });
  test('JSON subscription lists flatten full Xray and sing-box configs', () {
    final result = converted([
      {
        'outbounds': [xray()],
      },
      {
        'outbounds': [sing()],
      },
    ]);
    expect(result['proxies'], hasLength(2));
    expect(result['proxies'][0]['type'], 'vless');
    expect(result['proxies'][1]['type'], 'vless');
    expect(result['proxies'][0]['name'], isNot(result['proxies'][1]['name']));
  });
  test('sing-box plaintext Trojan keeps TLS disabled explicitly', () {
    final node = sing('trojan')..remove('tls');
    final config = converted({
      'outbounds': [node],
    });
    expect(config['proxies'][0]['skip-tls'], true);
    expect(
      converted({
        'outbounds': [sing('trojan')],
      })['proxies'][0]['skip-tls'],
      false,
    );
  });

  test('reads JSON comments, trailing commas and encoded JSON safely', () {
    const raw =
        '''{
      // connection settings
      "outbounds": [{
        "type":"vless", "tag":"https://example.com/,}",
        "server":"example.com", "server_port":443,
        "uuid":"$uuid", /* keep strings unchanged */
      },],
    }''';
    for (final input in [raw, base64Encode(utf8.encode(raw))]) {
      final output = jsonDecode(
        utf8.decode(
          convertForeignProfile(Uint8List.fromList(utf8.encode(input))),
        ),
      );
      expect(output['proxies'][0]['name'], 'https://example.com/,}');
    }
  });

  test('rejects cycles across groups and dialer chains', () {
    expect(
      () => converted({
        'outbounds': [
          {...sing(), 'tag': 'one', 'detour': 'pick'},
          {
            'type': 'selector',
            'tag': 'pick',
            'outbounds': ['one'],
          },
        ],
      }),
      throwsA(isA<ForeignProfileException>()),
    );
  });

  test('leaves native Clash, share links and encrypted files unchanged', () {
    for (final text in [
      'proxies: []',
      '{"proxies":[]}',
      '[{"name":"edge","type":"vless","server":"example.com","port":443}]',
      'vless://fixture@example.com:443',
      'age-encryption.org/v1\n',
    ]) {
      final bytes = Uint8List.fromList(utf8.encode(text));
      expect(convertForeignProfile(bytes), bytes);
    }
  });

  test('preserves sing-box TLS, Reality, gRPC and routing chains', () {
    final value = converted({
      'outbounds': [
        {
          ...sing(),
          'detour': 'hop',
          'flow': 'xtls-rprx-vision',
          'tls': {
            'enabled': true,
            'server_name': 'tls.example',
            'insecure': false,
            'alpn': ['h2'],
            'utls': {'enabled': true, 'fingerprint': 'firefox'},
            'reality': {
              'enabled': true,
              'public_key': 'fixture-key',
              'short_id': 'abcd',
            },
          },
          'transport': {'type': 'grpc', 'service_name': 'rpc'},
        },
        {...sing('shadowsocks'), 'tag': 'hop'},
        {'type': 'direct', 'tag': 'direct'},
        {
          'type': 'selector',
          'tag': 'pick',
          'outbounds': ['direct', 'edge'],
          'default': 'edge',
        },
      ],
    });
    final proxy = (value['proxies'] as List).first as Map;
    expect(proxy['dialer-proxy'], 'hop');
    expect(proxy['servername'], 'tls.example');
    expect(proxy['skip-cert-verify'], false);
    expect(proxy['client-fingerprint'], 'firefox');
    expect(proxy['reality-opts'], {
      'public-key': 'fixture-key',
      'short-id': 'abcd',
    });
    expect(proxy['grpc-opts'], {'grpc-service-name': 'rpc'});
    expect(value['proxy-groups'][0]['proxies'], ['edge', 'DIRECT']);
  });

  test('imports common sing-box protocols', () {
    for (final type in [
      'vless',
      'vmess',
      'trojan',
      'shadowsocks',
      'hysteria2',
      'tuic',
      'socks',
      'http',
    ]) {
      final result = converted(sing(type));
      expect(result['proxies'], hasLength(1));
      expect(result['proxies'][0]['port'], 443);
    }
  });

  test('preserves Xray user credentials, TLS and HTTP upgrade headers', () {
    final result = converted({
      'outbounds': [
        {
          ...xray(),
          'streamSettings': {
            'network': 'httpupgrade',
            'security': 'tls',
            'tlsSettings': {
              'serverName': 'tls.example',
              'alpn': ['http/1.1'],
              'allowInsecure': false,
            },
            'httpupgradeSettings': {
              'host': 'front.example',
              'path': '/upgrade',
            },
          },
        },
      ],
    });
    final proxy = result['proxies'][0];
    expect(proxy['uuid'], uuid);
    expect(proxy['tls'], true);
    expect(proxy['servername'], 'tls.example');
    expect(proxy['ws-opts'], {
      'path': '/upgrade',
      'headers': {'Host': 'front.example'},
      'v2ray-http-upgrade': true,
    });
  });

  test('imports Xray XHTTP without downgrading its transport', () {
    final result = converted({
      ...xray(),
      'streamSettings': {
        'network': 'xhttp',
        'security': 'tls',
        'tlsSettings': {'serverName': 'tls.example'},
        'xhttpSettings': {
          'host': 'front.example',
          'path': '/x',
          'mode': 'packet-up',
          'extra': {
            'xPaddingBytes': '100-200',
            'noGRPCHeader': true,
            'xmux': {'maxConcurrency': '8-16', 'hKeepAlivePeriod': 30},
          },
        },
      },
    });
    expect(result['proxies'][0]['network'], 'xhttp');
    expect(result['proxies'][0]['xhttp-opts']['mode'], 'packet-up');
    expect(result['proxies'][0]['xhttp-opts']['x-padding-bytes'], '100-200');
    expect(result['proxies'][0]['xhttp-opts']['reuse-settings'], {
      'max-concurrency': '8-16',
      'h-keep-alive-period': 30,
    });
  });

  test('rejects unsupported options atomically instead of dropping a node', () {
    for (final bad in [
      {
        ...sing(),
        'multiplex': {'enabled': true},
      },
      {
        ...sing(),
        'tls': {
          'enabled': true,
          'ech': {'enabled': true},
        },
      },
      {
        ...sing(),
        'tls': {
          'enabled': true,
          'reality': {'enabled': true},
        },
      },
      {
        ...sing(),
        'tls': {'enabled': 'true'},
      },
      {
        ...xray(),
        'streamSettings': {'security': 'reality', 'realitySettings': {}},
      },
      {
        ...sing(),
        'transport': {'type': 'quic'},
      },
      {...sing(), 'detour': 'missing'},
      {...sing(), 'server_port': 0},
      {
        ...xray(),
        'mux': {'enabled': true},
      },
      {
        ...xray(),
        'streamSettings': {'network': 'kcp'},
      },
    ]) {
      expect(
        () => converted({
          'outbounds': [
            {...sing(), 'tag': 'good'},
            bad,
          ],
        }),
        throwsA(isA<ForeignProfileException>()),
      );
    }
  });

  test('reports node index without exposing credentials', () {
    try {
      converted({
        'outbounds': [
          {...sing(), 'tag': 'good'},
          {...sing('trojan'), 'password': 'private-secret', 'unknown': true},
        ],
      });
      fail('Expected rejection');
    } on ForeignProfileException catch (error) {
      expect(error.node, 2);
      expect(error.format, 'sing-box');
      expect(error.toString(), isNot(contains('private-secret')));
    }
  });

  test('does not retain foreign listeners, DNS or rule policies', () {
    final result = converted({
      'outbounds': [sing()],
      'inbounds': [
        {'listen': '0.0.0.0'},
      ],
      'dns': {'servers': []},
      'route': {'final': 'direct'},
    });
    expect(result.keys, ['proxies']);
  });
}
