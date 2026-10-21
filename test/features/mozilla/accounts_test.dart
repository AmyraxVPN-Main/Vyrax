import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/features/mozilla/accounts.dart';
import 'package:fl_clash/features/mozilla/api.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryVault implements MozillaVault {
  String? value;
  bool failWrite = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    if (failWrite) throw StateError('storage unavailable');
    this.value = value;
  }
}

Map<String, dynamic> account(String email) => {
  'email': email,
  'accessToken': 'access',
  'refreshToken': 'refresh',
  'expiresAt': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
};

void main() {
  late MemoryVault vault;
  late MozillaAccounts accounts;
  var stopped = 0;
  var tokenRequests = 0;
  var statusActivated = false;
  String? freeTierStub;
  Map<String, String> tokenHeaders = {
    'x-quota-limit': '50000',
    'x-quota-remaining': '42000',
  };
  var verified = true;
  String? tokenBody;
  setUp(() {
    vault = MemoryVault();
    stopped = 0;
    tokenRequests = 0;
    statusActivated = false;
    freeTierStub = null;
    tokenHeaders = {'x-quota-limit': '50000', 'x-quota-remaining': '42000'};
    verified = true;
    tokenBody = null;
    accounts = MozillaAccounts(
      vault: vault,
      beforeAccountChange: () async {
        stopped++;
      },
      api: MozillaApi(
        request: (endpoint, {body = '', authorization = ''}) async {
          return switch (endpoint) {
            'login' => MozillaResponse(
              200,
              jsonEncode({'sessionToken': 'ab' * 32, 'verified': verified}),
            ),
            'verify' => const MozillaResponse(200, '{}'),
            'oauth' => const MozillaResponse(
              200,
              '{"access_token":"access","refresh_token":"refresh","expires_in":3600}',
            ),
            'activate' => MozillaResponse(
              200,
              freeTierStub ?? jsonEncode({'subscribed': statusActivated}),
            ),
            'status' => MozillaResponse(
              200,
              freeTierStub ??
                  jsonEncode({'subscribed': statusActivated, 'maxBytes': 50000}),
            ),
             'token' => (() {
              tokenRequests++;
              return MozillaResponse(
                200,
                tokenBody ?? '{"token":"runtime-pass"}',
                tokenHeaders,
              );
            })(),
            _ => throw StateError('unexpected endpoint $endpoint'),
          };
        },
      ),
    );
  });
  tearDown(() => accounts.dispose());

  test('closing login discards a late successful response', () async {
    final login = Completer<MozillaResponse>();
    final started = Completer<void>();
    final pendingAccounts = MozillaAccounts(
      vault: vault,
      beforeAccountChange: () async {
        stopped++;
      },
      api: MozillaApi(
        request: (endpoint, {body = '', authorization = ''}) {
          expect(endpoint, 'login');
          started.complete();
          return login.future;
        },
      ),
    );
    addTearDown(pendingAccounts.dispose);
    final work = pendingAccounts.signIn(
      'tester@example.com',
      'sample-password',
    );
    await started.future;
    pendingAccounts.cancelVerification();
    login.complete(
      MozillaResponse(
        200,
        jsonEncode({'sessionToken': 'ab' * 32, 'verified': true}),
      ),
    );
    await work;
    expect(pendingAccounts.signedIn, isFalse);
    expect(pendingAccounts.needsVerification, isFalse);
    expect(vault.value, isNull);
    expect(stopped, 0);
  });

  test(
    'explicitly expired proxy passes are rejected and never cached',
    () async {
      await accounts.signIn('tester@example.com', 'sample-password');
      tokenBody = '{"token":"expired-pass","expires_at":1}';
      await expectLater(accounts.proxyPass(), throwsA(isA<MozillaException>()));
      expect(accounts.cachedPass, isEmpty);
      final payload = base64Url
          .encode(utf8.encode('{"exp":1}'))
          .replaceAll('=', '');
      tokenBody = jsonEncode({'token': 'header.$payload.signature'});
      await expectLater(accounts.proxyPass(), throwsA(isA<MozillaException>()));
      expect(accounts.cachedPass, isEmpty);
      tokenBody = null;
      expect(await accounts.proxyPass(), 'runtime-pass');
    },
  );

  test('passwords and Firefox sessions are never persisted', () async {
    await accounts.signIn('tester@example.com', 'sample-password');
    expect(vault.value, isNot(contains('sample-password')));
    expect(vault.value, isNot(contains('sessionToken')));
    expect(accounts.signedIn, isTrue);
  });
  test('unverified login stays in memory until code verification', () async {
    verified = false;
    await accounts.signIn('tester@example.com', 'sample-password');
    expect(accounts.needsVerification, isTrue);
    expect(vault.value, isNull);
    await accounts.verify('123456');
    expect(accounts.needsVerification, isFalse);
    expect(accounts.signedIn, isTrue);
  });
  test('cancel removes the pending session', () async {
    verified = false;
    await accounts.signIn('tester@example.com', 'sample-password');
    accounts.cancelVerification();
    expect(accounts.needsVerification, isFalse);
    await expectLater(
      accounts.verify('123456'),
      throwsA(isA<MozillaException>()),
    );
  });
  test(
    '204 activation is confirmed by status and quota is server reported',
    () async {
      await accounts.signIn('tester@example.com', 'sample-password');
      statusActivated = true;
      await accounts.refresh(activate: true);
      expect(accounts.activated, isTrue);
      expect(accounts.quota['remaining'], 42000);
      expect(await accounts.proxyPass(), 'runtime-pass');
      expect(tokenRequests, 1);
      expect(vault.value, isNot(contains('runtime-pass')));
    },
  );
  test('unconfirmed activation surfaces a failure', () async {
    await accounts.signIn('tester@example.com', 'sample-password');
    await expectLater(
      accounts.refresh(activate: true),
      throwsA(
        isA<MozillaException>().having(
          (e) => e.reason,
          'reason',
          MozillaError.notActivated,
        ),
      ),
    );
    expect(accounts.activated, isFalse);
  });
  test('free tier works with limited_bandwidth and string quotas', () async {
    await accounts.signIn('tester@example.com', 'sample-password');
    await expectLater(
      accounts.refresh(activate: true),
      throwsA(isA<MozillaException>()),
    );
    statusActivated = false;
    freeTierStub = jsonEncode({
      'subscribed': false,
      'limited_bandwidth': true,
      'maxBytes': '53687091200',
    });
    tokenHeaders = {};
    await accounts.refresh(activate: true);
    expect(accounts.activated, isTrue);
    expect(accounts.quota['limit'], 53687091200);
    expect(await accounts.proxyPass(), 'runtime-pass');
  });
  test('concurrent pass requests share cached credentials', () async {
    await accounts.signIn('tester@example.com', 'sample-password');
    expect(await Future.wait([accounts.proxyPass(), accounts.proxyPass()]), [
      'runtime-pass',
      'runtime-pass',
    ]);
    expect(tokenRequests, 1);
  });
  test('only active account removal stops the free connection', () async {
    vault.value = jsonEncode({
      'activeEmail': 'first@example.com',
      'accounts': [account('first@example.com'), account('second@example.com')],
    });
    await accounts.initialize();
    await accounts.removeAccount('second@example.com');
    expect(stopped, 0);
    await accounts.removeAccount('first@example.com');
    expect(stopped, 1);
    expect(accounts.signedIn, isFalse);
    await expectLater(accounts.proxyPass(), throwsA(isA<MozillaException>()));
  });
  test('account switching invalidates the previous proxy pass', () async {
    vault.value = jsonEncode({
      'activeEmail': 'first@example.com',
      'accounts': [account('first@example.com'), account('second@example.com')],
    });
    await accounts.proxyPass();
    await accounts.switchAccount('second@example.com');
    await accounts.proxyPass();
    expect(tokenRequests, 2);
    expect(stopped, 1);
  });
  test('write failure keeps previous saved accounts', () async {
    vault.value = jsonEncode({
      'activeEmail': 'first@example.com',
      'accounts': [account('first@example.com')],
    });
    await accounts.initialize();
    vault.failWrite = true;
    await expectLater(
      accounts.removeAccount('first@example.com'),
      throwsA(isA<MozillaException>()),
    );
    expect(accounts.email, 'first@example.com');
    expect(accounts.signedIn, isTrue);
  });
  test('corrupt storage is not overwritten', () async {
    vault.value = 'broken';
    await expectLater(accounts.initialize(), throwsA(isA<MozillaException>()));
    await expectLater(
      accounts.signIn('tester@example.com', 'sample-password'),
      throwsA(isA<MozillaException>()),
    );
    expect(vault.value, 'broken');
  });
}
