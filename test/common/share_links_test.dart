import 'dart:convert';

import 'package:fl_clash/common/share_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseShareLinkList', () {
    test('parses a vless reality link list', () {
      const links = '''
# free servers
vless://8f2e...-uuid@example.com:443?security=reality&sni=www.microsoft.com&pbk=PUBKEY&sid=ab12&fp=chrome&type=tcp&flow=xtls-rprx-vision#Node1
trojan://pass123@1.2.3.4:443?sni=example.org#Trojan%20Node
ss://YWVzLTI1Ni1nY206cGFzc3dvcmQ=@5.6.7.8:8388#SS%20Node
''';
      final proxies = parseShareLinkList(links);
      expect(proxies, isNotNull);
      expect(proxies!.length, 3);
      expect(proxies[0]['type'], 'vless');
      expect(proxies[0]['server'], 'example.com');
      expect(proxies[0]['port'], 443);
      expect(proxies[0]['tls'], true);
      expect(
        (proxies[0]['reality-opts'] as Map)['public-key'],
        'PUBKEY',
      );
      expect(proxies[1]['type'], 'trojan');
      expect(proxies[1]['password'], 'pass123');
      expect(proxies[1]['sni'], 'example.org');
      expect(proxies[2]['type'], 'ss');
      expect(proxies[2]['cipher'], 'aes-256-gcm');
      expect(proxies[2]['password'], 'password');
      expect(proxies[0]['name'], 'Node1');
    });

    test('parses base64-wrapped lists and dedupes names', () {
      final links = [
        'vless://u1@host1.com:443?security=tls#Same',
        'vless://u2@host2.com:443?security=tls#Same',
      ].join('\n');
      // The base64 wrapper is unwrapped by convertForeignProfile before
      // the parser sees the plain list.
      final wrapped = utf8.decode(base64.decode(base64.encode(utf8.encode(links))));
      final proxies = parseShareLinkList(wrapped);
      expect(proxies, isNotNull);
      expect(proxies!.length, 2);
      expect(proxies[0]['name'], isNot(proxies[1]['name']));
    });

    test('rejects non link text', () {
      expect(parseShareLinkList('hello world'), isNull);
      expect(parseShareLinkList('{"proxies": []}'), isNull);
      expect(parseShareLinkList(''), isNull);
    });

    test('parses vmess base64 json links', () {
      final vmess = base64.encode(
        utf8.encode(
          jsonEncode({
            'add': 'vm.example.com',
            'port': '2053',
            'id': 'uuid-xyz',
            'aid': '0',
            'scy': 'auto',
            'net': 'ws',
            'host': 'vm.example.com',
            'path': '/ws',
            'tls': 'tls',
            'sni': 'vm.example.com',
          }),
        ),
      );
      final proxies = parseShareLinkList('vmess://$vmess');
      expect(proxies, isNotNull);
      expect(proxies!.length, 1);
      expect(proxies[0]['type'], 'vmess');
      expect(proxies[0]['network'], 'ws');
      expect(proxies[0]['tls'], true);
      expect(proxies[0]['servername'], 'vm.example.com');
    });
  });
}
