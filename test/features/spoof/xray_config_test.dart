import 'package:fl_clash/features/spoof/models.dart';
import 'package:fl_clash/features/spoof/xray_config.dart';
import 'package:flutter_test/flutter_test.dart';

SpoofProfile _vless() => parseSpoofShareLink(
  'vless://uuid@example.com:443?security=tls&sni=example.com'
  '&type=ws&host=cdn.example.com&path=%2Fws',
).copyWith(fragment: SpoofFragmentSettings.full5);

SpoofProfile _reality() => parseSpoofShareLink(
  'vless://uuid@example.com:443?type=tcp&security=reality'
  '&pbk=PUBKEY&sid=abcd&fp=chrome&sni=www.example.net',
);

SpoofProfile _trojan() => parseSpoofShareLink(
  'trojan://pass@example.com:443?security=tls&type=ws&path=%2Fws',
);

void main() {
  group('iranDirectRules', () {
    test('applies private, iran geosite and geoip to direct', () {
      final rules = iranDirectRules();
      expect(rules, hasLength(3));
      expect(rules[0]['outboundTag'], 'direct');
      expect(rules[0]['ip'], ['geoip:private']);
      expect(rules[1]['domain'], ['geosite:category-ir', r'regexp:\.ir$']);
      expect(rules[2]['ip'], ['geoip:ir']);
      for (final rule in rules) {
        expect(rule['type'], 'field');
      }
    });
  });

  group('buildSpoofInbounds', () {
    test('exposes socks and http inbounds on loopback', () {
      final inbounds = buildSpoofInbounds(
        socksPort: 21801,
        httpPort: 21802,
        iranDirect: false,
      );
      expect(inbounds, hasLength(2));
      expect(inbounds[0]['port'], 21801);
      expect(inbounds[0]['protocol'], 'socks');
      expect(inbounds[0]['listen'], '127.0.0.1');
      expect(inbounds[1]['port'], 21802);
      expect(inbounds[1]['protocol'], 'http');
      expect(inbounds[0]['sniffing'], isNull);
    });

    test('adds route only sniffing when iran direct is enabled', () {
      final inbounds = buildSpoofInbounds(
        socksPort: 20808,
        httpPort: 20809,
        iranDirect: true,
      );
      for (final inbound in inbounds) {
        final sniffing = inbound['sniffing'] as Map<String, dynamic>;
        expect(sniffing['enabled'], isTrue);
        expect(sniffing['routeOnly'], isTrue);
        expect(sniffing['destOverride'], ['http', 'tls']);
      }
    });
  });

  group('buildProxyOutbound', () {
    test('uses edge over host for non-reality tls profile', () {
      final outbound = buildProxyOutbound(
        _vless().copyWith(edge: '104.18.1.1'),
      );
      expect(outbound['tag'], 'proxy');
      expect(outbound['protocol'], 'vless');
      final vnext = (outbound['settings'] as Map<String, dynamic>)['vnext']
          as List<Map<String, dynamic>>;
      expect(vnext[0]['address'], '104.18.1.1');
      final stream = outbound['streamSettings'] as Map<String, dynamic>;
      expect(stream['network'], 'ws');
      expect(stream['security'], 'tls');
      final fragment = stream['finalmask'] as Map<String, dynamic>;
      final tcp = (fragment['tcp'] as List<Map<String, dynamic>>)[0];
      expect(tcp['type'], 'fragment');
      expect(
        tcp['settings'],
        SpoofFragmentSettings.full5.toJson(),
      );
      final sockopt = stream['sockopt'] as Map<String, dynamic>;
      expect(sockopt['domainStrategy'], 'UseIPv4');
    });

    test('reality uses host directly and skips fragment', () {
      final profile = _reality().copyWith(
        edge: '104.18.1.1',
        fragment: SpoofFragmentSettings.full5,
      );
      final outbound = buildProxyOutbound(profile);
      final stream = outbound['streamSettings'] as Map<String, dynamic>;
      expect(
        (outbound['settings']
                as Map<String, dynamic>)['vnext'][0]['address'],
        'example.com',
      );
      expect(stream['security'], 'reality');
      final reality = stream['realitySettings'] as Map<String, dynamic>;
      expect(reality['publicKey'], 'PUBKEY');
      expect(reality['shortId'], 'abcd');
      expect(reality['fingerprint'], 'chrome');
      expect(stream['finalmask'], isNull);
    });

    test('trojan password outbound and raw transport fallback', () {
      final settings = buildProxyOutbound(
        parseSpoofShareLink('trojan://pass@fallback.example:700?type=tcp'),
      );
      expect(settings['protocol'], 'trojan');
      final servers =
          (settings['settings'] as Map<String, dynamic>)['servers']
              as List<Map<String, dynamic>>;
      expect(servers[0]['address'], 'fallback.example');
      expect(servers[0]['password'], 'pass');
      final stream = settings['streamSettings'] as Map<String, dynamic>;
      expect(stream['network'], 'raw');
      expect(
        (stream['rawSettings'] as Map<String, dynamic>)['header']['type'],
        'none',
      );
      expect((stream['sockopt'] as Map<String, dynamic>)['domainStrategy'],
          'UseIPv4');
    });

    test('throws for unsupported protocol', () {
      final profile = parseSpoofShareLink(
        'trojan://pass@example.com:443',
      );
      expect(
        () => buildProxyOutbound(
          SpoofProfile(
            id: profile.id,
            label: profile.label,
            sourceUri: profile.sourceUri,
            protocol: 'ss',
            host: profile.host,
            port: profile.port,
            authId: profile.authId,
            encryption: profile.encryption,
            security: profile.security,
            network: profile.network,
            sni: profile.sni,
            hostHeader: profile.hostHeader,
            path: profile.path,
            serviceName: profile.serviceName,
            mode: profile.mode,
            fingerprint: profile.fingerprint,
            realityPublicKey: profile.realityPublicKey,
            realityShortId: profile.realityShortId,
            realitySpiderX: profile.realitySpiderX,
            edge: profile.edge,
            fragment: profile.fragment,
            mux: profile.mux,
            countryCode: profile.countryCode,
          ),
        ),
        throwsFormatException,
      );
    });

    test('mux block is emitted only when enabled and not reality', () {
      final muxed = buildProxyOutbound(_trojan().copyWith(mux: true));
      expect(
        (muxed['mux'] as Map<String, dynamic>)['enabled'],
        isTrue,
      );
      final plain = buildProxyOutbound(_trojan());
      expect(plain.containsKey('mux'), isFalse);
      final realityMux = buildProxyOutbound(
        _reality().copyWith(mux: true),
      );
      expect(realityMux.containsKey('mux'), isFalse);
    });
  });

  group('buildSpoofXrayConfig', () {
    test('produces full config with routing and fallback outbounds', () {
      final config = buildSpoofXrayConfig(
        profile: _vless(),
        socksPort: 21811,
        httpPort: 21812,
        iranDirect: true,
        bypassProcesses: const ['vyrax.exe'],
      );
      expect((config['log'] as Map)['loglevel'], 'warning');
      expect((config['inbounds'] as List), hasLength(2));
      final outbounds = config['outbounds'] as List<Map<String, dynamic>>;
      expect(outbounds[0]['tag'], 'proxy');
      expect(outbounds[1]['tag'], 'direct');
      expect(outbounds[2]['tag'], 'block');
      final rules = (config['routing']
          as Map<String, dynamic>)['rules'] as List<Map<String, dynamic>>;
      expect(rules.first['process'], ['vyrax.exe']);
      expect(rules, hasLength(1 + iranDirectRules().length));
      expect((config['routing'] as Map)['domainStrategy'], 'AsIs');
    });

    test('routing is empty when iranDirect is false', () {
      final config = buildSpoofXrayConfig(
        profile: _vless(),
        iranDirect: false,
      );
      expect(
        ((config['routing'] as Map)['rules'] as List),
        isEmpty,
      );
    });

    test('constants match spoof port plan and MCI edges', () {
      expect(kSpoofSocksPort, 20808);
      expect(kSpoofHttpPort, 20809);
      expect(kSpoofDefaultUdpPort, 40443);
      expect(kSpoofPortScanStart, 38408);
      expect(kMciPrimaryEdge, '104.18.1.1');
      expect(kMciFallbackEdge, '172.66.0.1');
      expect(kBaseEdge, '104.18.32.47');
      expect(kBaseFallbackEdge, '172.64.155.209');
    });
  });
}
