import 'dart:convert';

import 'package:fl_clash/features/spoof/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseSpoofShareLink', () {
    test('parses vless tls ws link with title', () {
      final profile = parseSpoofShareLink(
        'vless://8f2c1e34-90ab-4d3f-9f2a-1234567890ab'
        '@example.com:443?encryption=none&security=tls&sni=example.com'
        '&type=ws&host=cdn.example.com&path=%2Fws#My%20Server',
      );
      expect(profile.protocol, 'vless');
      expect(profile.host, 'example.com');
      expect(profile.port, 443);
      expect(profile.authId, '8f2c1e34-90ab-4d3f-9f2a-1234567890ab');
      expect(profile.security, 'tls');
      expect(profile.network, 'ws');
      expect(profile.sni, 'example.com');
      expect(profile.hostHeader, 'cdn.example.com');
      expect(profile.path, '/ws');
      expect(profile.label, 'My Server');
      expect(profile.isReality, isFalse);
      expect(profile.hasFragment, isFalse);
      expect(profile.id, startsWith('spoof-vless-'));
    });

    test('normalizes tcp network to raw and infers tls from tls=1', () {
      final profile = parseSpoofShareLink(
        'trojan://pass@example.com:443?tls=1&type=tcp',
      );
      expect(profile.protocol, 'trojan');
      expect(profile.network, 'raw');
      expect(profile.security, 'tls');
      expect(profile.sni, 'example.com');
      expect(profile.hostHeader, 'example.com');
    });

    test('detects reality from pbk and keeps fragment disabled', () {
      final profile = parseSpoofShareLink(
        'vless://uuid@example.com:443'
        '?type=tcp&security=reality&pbk=PUBKEY&sid=abcd'
        '&fp=chrome&sni=www.example.net&spx=%2F',
      );
      expect(profile.isReality, isTrue);
      expect(profile.realityPublicKey, 'PUBKEY');
      expect(profile.realityShortId, 'abcd');
      expect(profile.fingerprint, 'chrome');
      expect(profile.realitySpiderX, '/');
    });

    test('parses vmess base64 json link', () {
      final json = {
        'add': 'vm.example.com',
        'port': '8443',
        'id': 'b831381d-6324-4d53-ad4f-8cda48b30811',
        'ps': 'Test VMess',
        'net': 'ws',
        'host': 'cdn.vm.example.com',
        'path': '/ray',
        'tls': 'tls',
        'scy': 'auto',
      };
      final link = 'vmess://${base64Encode(utf8.encode(jsonEncode(json)))}';
      final profile = parseSpoofShareLink(link);
      expect(profile.protocol, 'vmess');
      expect(profile.host, 'vm.example.com');
      expect(profile.port, 8443);
      expect(profile.authId, 'b831381d-6324-4d53-ad4f-8cda48b30811');
      expect(profile.network, 'ws');
      expect(profile.security, 'tls');
      expect(profile.label, 'Test VMess');
      expect(profile.hostHeader, 'cdn.vm.example.com');
    });

    test('throws on unsupported scheme and missing user info', () {
      expect(
        () => parseSpoofShareLink('ss://YWVz@example.com:8388'),
        throwsA(isA<SpoofShareLinkException>()),
      );
      expect(
        () => parseSpoofShareLink('vless://example.com:443?security=tls'),
        throwsA(isA<SpoofShareLinkException>()),
      );
    });

    test('parses same link to same stable id', () {
      const link =
          'trojan://pass@example.com:443?security=tls&sni=example.com&type=ws&path=%2Fws';
      final first = parseSpoofShareLink(link);
      final second = parseSpoofShareLink(link);
      expect(first.id, second.id);
    });
  });

  group('SpoofFragmentSettings', () {
    test('presets expose expected ranges', () {
      expect(SpoofFragmentSettings.full5.length, '5-5');
      expect(SpoofFragmentSettings.full5.delay, '5-5');
      expect(SpoofFragmentSettings.full10.length, '10-10');
      expect(SpoofFragmentSettings.full20.length, '20-20');
      expect(SpoofFragmentSettings.multi64.length, '64-64');
      expect(SpoofFragmentSettings.gfwFirst.length, '1-3');
      expect(SpoofFragmentSettings.gfwFirst.maxSplit, '2-2');
      expect(SpoofFragmentSettings.full5.hasFragment, isTrue);
    });

    test('forStrategy maps non-plain strategies and json round trip', () {
      final settings = SpoofFragmentSettings.forStrategy(
        SpoofFragmentStrategy.full20,
      );
      expect(settings.length, '20-20');
      final restored = SpoofFragmentSettings.fromJson(settings.toJson());
      expect(restored.length, settings.length);
      expect(restored.delay, settings.delay);
      expect(restored.packets, settings.packets);
      expect(restored.toJson(), settings.toJson());
      expect(restored.hasFragment, isTrue);
    });

    test('plain settings serialize without length and maxSplit key', () {
      const plain = SpoofFragmentSettings();
      expect(plain.hasFragment, isFalse);
      expect(plain.toJson(), {
        'packets': 'tlshello',
        'length': '',
        'delay': '0-0',
      });
    });
  });

  group('SpoofProfile serialization', () {
    test('json round trip keeps identity and probe data', () {
      final profile = parseSpoofShareLink(
        'trojan://pass@example.com:443?security=tls&type=ws#Edge',
      ).copyWith(
        edge: '104.18.1.1',
        countryCode: 'MCI',
        lastProbeMs: 350,
        lastProbeAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      final restored = SpoofProfile.fromJson(profile.toJson());
      expect(restored.id, profile.id);
      expect(restored.edge, '104.18.1.1');
      expect(restored.countryCode, 'MCI');
      expect(restored.lastProbeMs, 350);
      expect(
        restored.lastProbeAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      expect(restored.displayLabel, 'Edge');
    });

    test('displayLabel falls back to host:port', () {
      final profile = parseSpoofShareLink('trojan://pass@example.com:443');
      expect(profile.displayLabel, 'example.com:443');
    });
  });

  group('SpoofBundle', () {
    test('label summarizes count and json round trips', () {
      final servers = [
        parseSpoofShareLink('trojan://pass@a.example:443?security=tls#One'),
        parseSpoofShareLink('trojan://pass@b.example:443?security=tls#Two'),
      ];
      const empty = SpoofBundle(id: 'spoof-bundle-1', servers: []);
      expect(empty.label, '');
      expect(empty.isEmpty, isTrue);
      final created = SpoofBundle(
        id: 'spoof-bundle-2',
        servers: servers,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      expect(created.label, 'One +1');
      expect(created.isEmpty, isFalse);
      final restored = SpoofBundle.fromJson(created.toJson());
      expect(restored.id, created.id);
      expect(restored.servers, hasLength(2));
      expect(restored.servers[1].label, 'Two');
      expect(
        restored.createdAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      expect(restored.label, 'One +1');
    });
  });
}
