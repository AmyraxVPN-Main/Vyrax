import 'package:fl_clash/features/mozilla/api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('password derivation agrees with Vyrax WebCrypto', () {
    expect(
      MozillaApi.derivePassword('tester@example.com', 'sample-password'),
      '4f92a069c385719693c12264596fb0ea8d6f22ed48ed7128318db4167af161d0',
    );
  });
  test('Hawk signature agrees with Vyrax WebCrypto', () {
    expect(
      MozillaApi.hawk(
        'ab' * 32,
        'oauth',
        '{}',
        timestamp: 1700000000,
        nonce: 'sample12',
      ),
      'Hawk id="d36adccff00b16274cd9be5aa570fd8fada54aa5413e6c902d25f656303b1ef6", ts="1700000000", nonce="sample12", mac="cQYCd9F+XhLtFmrMRpoh7n48c4RTkKP4wuow/SSDcN8=", hash="vNZvU+y3rJKqH4hu1yxrNuaijNPgIJ2Rgj/sHzsQhXY="',
    );
  });
  test('normalizes invisible characters in email', () {
    expect(
      MozillaApi.normalizeEmail(' Tester\u200b@Example.COM '),
      'tester@example.com',
    );
  });
  test('challenge and quota errors stay distinct', () {
    for (final entry in {
      406: MozillaError.challenge,
      429: MozillaError.quota,
      403: MozillaError.eligibility,
      401: MozillaError.auth,
    }.entries) {
      expect(
        () => MozillaResponse(entry.key, '<html>error</html>').json(),
        throwsA(
          isA<MozillaException>().having(
            (e) => e.reason,
            'reason',
            entry.value,
          ),
        ),
      );
    }
  });
  test('rejects malformed success and unsafe secrets', () {
    expect(
      () => const MozillaResponse(200, '<html>').json(),
      throwsA(isA<MozillaException>()),
    );
    expect(
      () => MozillaApi.tokens('tester@example.com', {
        'access_token': 'bad\r\nheader',
        'refresh_token': 'refresh',
      }),
      throwsA(isA<MozillaException>()),
    );
  });
  test('Hawk cannot authorize arbitrary endpoints', () {
    expect(
      () => MozillaApi.hawk('ab' * 32, 'https://example.com', '{}'),
      throwsA(isA<MozillaException>()),
    );
  });
}
