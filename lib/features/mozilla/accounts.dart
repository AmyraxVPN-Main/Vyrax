import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'catalog.dart';
import 'flags.dart';

abstract interface class MozillaVault {
  Future<String?> read();
  Future<void> write(String value);
}

class MozillaAccounts extends ChangeNotifier {
  MozillaAccounts({
    required this.vault,
    MozillaApi? api,
    required this.beforeAccountChange,
  }) : api = api ?? MozillaApi();

  final MozillaVault vault;
  final MozillaApi api;
  final Future<void> Function() beforeAccountChange;
  List<Map<String, dynamic>> _accounts = [];
  String _email = '';
  String _pass = '';
  int _passExpiry = 0;
  Map<String, dynamic>? _pending;
  Future<void>? _initializing;
  Future<void> _queue = Future.value();
  bool _disposed = false;
  String? _checkpoint;
  int _authGeneration = 0;

  List<String> get emails =>
      List.unmodifiable(_accounts.map((a) => a['email'] as String));
  String get email => _email;
  bool get signedIn => _accounts.any((a) => a['email'] == _email);
  bool get needsVerification => _pending != null;
  Map<String, dynamic> get _account => _accounts.firstWhere(
    (a) => a['email'] == _email,
    orElse: () => throw const MozillaException(MozillaError.auth),
  );
  bool get activated => signedIn && _account['activated'] == true;
  Map<String, dynamic> get quota => signedIn && _account['quota'] is Map
      ? Map<String, dynamic>.from(_account['quota'] as Map)
      : {};
  bool get passNeedsRenewal => _pass.isEmpty || _passExpiry <= _now + 90;
  String get cachedPass => _pass;
  int get _now => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  Future<void> initialize() => _initializing ??= _load();
  Future<void> _load() async {
    try {
      final value = await vault.read();
      if (value != null) {
        final data = jsonDecode(value) as Map;
        final accounts = (data['accounts'] as List)
            .map((a) => Map<String, dynamic>.from(a as Map))
            .toList();
        if (accounts.length > 10 ||
            accounts.any(
              (a) => a['email'] is! String || a['refreshToken'] is! String,
            )) {
          throw const FormatException();
        }
        _accounts = accounts;
        _email = data['activeEmail'] as String? ?? '';
        if (!signedIn) _email = emails.firstOrNull ?? '';
      }
      _notify();
    } catch (_) {
      throw const MozillaException(MozillaError.storage);
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<T> _run<T>(Future<T> Function() operation) {
    final result = _queue.then((_) async {
      await initialize();
      _checkpoint = jsonEncode({'accounts': _accounts, 'activeEmail': _email});
      try {
        return await operation();
      } catch (_) {
        final data = jsonDecode(_checkpoint!) as Map;
        _accounts = (data['accounts'] as List)
            .map((a) => Map<String, dynamic>.from(a as Map))
            .toList();
        _email = data['activeEmail'] as String;
        _pass = '';
        _passExpiry = 0;
        rethrow;
      } finally {
        _notify();
      }
    });
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _persist() async {
    try {
      await vault.write(
        jsonEncode({'accounts': _accounts, 'activeEmail': _email}),
      );
      _checkpoint = jsonEncode({'accounts': _accounts, 'activeEmail': _email});
    } catch (_) {
      throw const MozillaException(MozillaError.storage);
    }
  }

  Future<void> signIn(String email, String password) {
    final generation = ++_authGeneration;
    return _run(() async {
      if (_accounts.length >= 10 &&
          !emails.contains(MozillaApi.normalizeEmail(email))) {
        throw const MozillaException(MozillaError.accounts);
      }
      _pending = null;
      final session = await api.login(email, password);
      if (_disposed || generation != _authGeneration) return;
      _pending = session;
      if (session['verified'] == true) await _finish(generation);
    });
  }

  Future<void> verify(String code) {
    final generation = _authGeneration;
    return _run(() async {
      final pending = _pending;
      if (pending == null) throw const MozillaException(MozillaError.auth);
      await api.verify(pending['sessionToken'] as String, code);
      if (_disposed || generation != _authGeneration) return;
      await _finish(generation);
    });
  }

  void cancelVerification() {
    _authGeneration++;
    _pending = null;
    _notify();
  }

  Future<void> _finish(int generation) async {
    final pending = _pending;
    if (pending == null) throw const MozillaException(MozillaError.auth);
    final tokens = await api.authorize(pending);
    if (_disposed || generation != _authGeneration) return;
    await beforeAccountChange();
    if (_disposed || generation != _authGeneration) return;
    _accounts.removeWhere((a) => a['email'] == tokens['email']);
    _accounts.add(tokens);
    _email = tokens['email'] as String;
    _pass = '';
    _passExpiry = 0;
    await _persist();
    _pending = null;
  }

  Future<String> _access() async {
    final account = _account;
    if (account['accessToken'] is String &&
        (mozillaJsonNum(account['expiresAt']) ?? 0) > _now + 60) {
      return account['accessToken'] as String;
    }
    final response = await api.request(
      'oauth',
      body: jsonEncode({
        'client_id': MozillaApi.clientId,
        'grant_type': 'refresh_token',
        'refresh_token': account['refreshToken'],
        'scope': MozillaApi.scope,
      }),
    );
    if ({400, 401, 403}.contains(response.status)) {
      throw const MozillaException(MozillaError.auth);
    }
    account.addAll(
      MozillaApi.tokens(
        _email,
        response.json(),
        previousRefresh: account['refreshToken'] as String,
      ),
    );
    await _persist();
    return account['accessToken'] as String;
  }

  Future<MozillaResponse> _authorized(String endpoint) async {
    var result = await api.request(
      endpoint,
      authorization: 'Bearer ${await _access()}',
    );
    if (result.status == 401 || result.status == 403) {
      _account['expiresAt'] = 0;
      result = await api.request(
        endpoint,
        authorization: 'Bearer ${await _access()}',
      );
    }
    return result;
  }

  void _quota(MozillaResponse response, [Map<String, dynamic>? data]) {
    final previous = quota;
    final values = <String, dynamic>{};
    for (final key in ['limit', 'remaining', 'reset']) {
      values[key] = mozillaJsonNum(response.headers['x-quota-$key']);
    }
    values['limit'] ??= mozillaJsonNum(data?['maxBytes']) ?? previous['limit'];
    _account['quota'] = values;
    if (data != null &&
        ((data['subscribed'] is bool) || (data['limited_bandwidth'] is bool))) {
      // FoxyVPN parity: free-tier accounts work with limited_bandwidth, the
      // `subscribed` flag only marks paid subscriptions.
      _account['activated'] =
          data['subscribed'] == true || data['limited_bandwidth'] == true;
    }
  }

  Future<void> refresh({bool activate = false}) => _run(() async {
    var response = await _authorized(activate ? 'activate' : 'status');
    var data = response.json();
    _quota(response, data);
    if (activate && !activated) {
      response = await _authorized('status');
      data = response.json();
      _quota(response, data);
      if (!activated) {
        // FoxyVPN parity: activation must show an entitlement (paid
        // subscription or free limited_bandwidth tier).
        throw const MozillaException(MozillaError.notActivated);
      }
    }
    if (activated) {
      response = await _authorized('token');
      if (response.status == 429) {
        _quota(response);
        (_account['quota'] as Map)['remaining'] = 0;
        _pass = '';
        _passExpiry = 0;
      } else {
        _cachePass(response);
      }
    }
    await _persist();
  });

  void _cachePass(MozillaResponse response) {
    final data = response.json();
    final token = data['token'];
    if (token is! String ||
        token.isEmpty ||
        token.length > 16384 ||
        RegExp(r'[\s\x00-\x1f\x7f]').hasMatch(token)) {
      throw const MozillaException(MozillaError.auth);
    }
    _passExpiry = mozillaJsonNum(data['expires_at']) ?? 0;
    if (_passExpiry == 0) {
      try {
        _passExpiry =
            (jsonDecode(
                      utf8.decode(
                        base64Url.decode(
                          base64Url.normalize(token.split('.')[1]),
                        ),
                      ),
                    )['exp']
                    as num)
                .toInt();
      } catch (_) {
        _passExpiry = _now + 300;
      }
    }
    if (_passExpiry <= _now) {
      _pass = '';
      throw const MozillaException(MozillaError.auth);
    }
    _pass = token;
    _quota(response);
    _account['activated'] = true;
  }

  Future<String> proxyPass() => _run(() async {
    if (passNeedsRenewal) {
      _cachePass(await _authorized('token'));
      await _persist();
    }
    return _pass;
  });

  Future<List<Map<String, dynamic>>> servers() async {
    final countryCodes = <String, String>{};
    final proxies = parseMozillaServers(
      (await api.request('servers')).json(),
      countryCodes: countryCodes,
    );
    await mozillaFlags.update(countryCodes);
    return proxies;
  }

  Future<void> switchAccount(String email) => _run(() async {
    if (!emails.contains(email)) {
      throw const MozillaException(MozillaError.auth);
    }
    if (email == _email) return;
    await beforeAccountChange();
    _email = email;
    _pass = '';
    _passExpiry = 0;
    await _persist();
  });

  Future<void> removeAccount(String email) => _run(() async {
    if (email == _email) await beforeAccountChange();
    _accounts.removeWhere((a) => a['email'] == email);
    if (_email == email) {
      _email = emails.firstOrNull ?? '';
      _pass = '';
      _passExpiry = 0;
    }
    await _persist();
  });

  @override
  void dispose() {
    _disposed = true;
    _pending = null;
    _pass = '';
    _accounts = [];
    super.dispose();
  }
}
