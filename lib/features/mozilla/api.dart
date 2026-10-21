// Firefox Accounts / Guardian protocol adapted from FoxyVPN, copyright 2026 Vauth (MIT).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart';

enum MozillaError {
  network,
  service,
  credentials,
  verification,
  challenge,
  eligibility,
  auth,
  quota,
  storage,
  accounts,
  noServers,
  notActivated,
}

class MozillaException implements Exception {
  const MozillaException(this.reason);
  final MozillaError reason;
  @override
  String toString() => 'Mozilla: ${reason.name}';
}

class MozillaResponse {
  const MozillaResponse(this.status, this.body, [this.headers = const {}]);
  final int status;
  final String body;
  final Map<String, String> headers;

  Map<String, dynamic> json() {
    Map<String, dynamic> data = {};
    var parsed = false;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
        parsed = true;
      }
    } on FormatException {
      /* HTTP errors may have a non-JSON body. */
    }
    if (status >= 200 && status < 300) {
      if (!parsed && body.trim().isNotEmpty) {
        throw const MozillaException(MozillaError.service);
      }
      return data;
    }
    throw MozillaException(switch (status) {
      406 => MozillaError.challenge,
      429 => MozillaError.quota,
      403 => MozillaError.eligibility,
      401 => MozillaError.auth,
      _ => switch (data['errno']) {
        102 || 103 => MozillaError.credentials,
        104 || 105 => MozillaError.verification,
        _ => MozillaError.service,
      },
    });
  }
}

typedef MozillaRequest =
    Future<MozillaResponse> Function(
      String endpoint, {
      String body,
      String authorization,
    });

class MozillaApi {
  MozillaApi({MozillaRequest? request}) : request = request ?? send;
  static const clientId = '5882386c6d801776';
  static const scope = 'profile https://identity.mozilla.com/apps/vpn';
  static const endpoints = {
    'login': 'https://api.accounts.firefox.com/v1/account/login',
    'verify': 'https://api.accounts.firefox.com/v1/session/verify_code',
    'oauth': 'https://api.accounts.firefox.com/v1/oauth/token',
    'servers':
        'https://firefox.settings.services.mozilla.com/v1/buckets/main/collections/vpn-serverlist/records',
    'status': 'https://vpn.mozilla.org/api/v1/fpn/status',
    'activate': 'https://vpn.mozilla.org/api/v1/fpn/activate',
    'token': 'https://vpn.mozilla.org/api/v1/fpn/token',
  };
  final MozillaRequest request;

  static Future<MozillaResponse> send(
    String endpoint, {
    String body = '',
    String authorization = '',
    String? proxy,
  }) async {
    final address = endpoints[endpoint];
    if (address == null ||
        body.length > 32768 ||
        authorization.contains(RegExp(r'[\r\n]'))) {
      throw const MozillaException(MozillaError.service);
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..badCertificateCallback = (_, _, _) => false;
    if (proxy != null) client.findProxy = (_) => proxy;
    try {
      return await (() async {
        final method =
            {'login', 'verify', 'oauth', 'activate'}.contains(endpoint)
            ? 'POST'
            : 'GET';
        final outgoing = await client.openUrl(method, Uri.parse(address));
        outgoing.followRedirects = false;
        outgoing.headers.set(
          HttpHeaders.userAgentHeader,
          'Vyrax Mozilla-compatible client',
        );
        outgoing.headers.set(HttpHeaders.acceptHeader, 'application/json');
        if (authorization.isNotEmpty) {
          outgoing.headers.set(HttpHeaders.authorizationHeader, authorization);
        }
        if (method == 'POST') {
          outgoing.headers.contentType = ContentType.json;
          outgoing.write(body);
        }
        final response = await outgoing.close();
        final bytes = <int>[];
        await for (final chunk in response) {
          if (bytes.length + chunk.length > 1048576) {
            throw const MozillaException(MozillaError.service);
          }
          bytes.addAll(chunk);
        }
        return MozillaResponse(response.statusCode, utf8.decode(bytes), {
          for (final key in [
            'x-quota-limit',
            'x-quota-remaining',
            'x-quota-reset',
          ])
            key: ?response.headers.value(key),
        });
      })().timeout(const Duration(seconds: 20));
    } on MozillaException {
      rethrow;
    } catch (_) {
      throw const MozillaException(MozillaError.network);
    } finally {
      client.close(force: true);
    }
  }

  static String normalizeEmail(String email) =>
      email.replaceAll(RegExp(r'[\s\u200b-\u200d\ufeff]'), '').toLowerCase();

  static List<int> _hkdf(List<int> input, String info, int length) {
    final key = Hmac(sha256, List<int>.filled(32, 0)).convert(input).bytes;
    final result = <int>[];
    var previous = <int>[];
    for (var i = 1; result.length < length; i++) {
      previous = Hmac(sha256, key).convert([
        ...previous,
        ...utf8.encode('identity.mozilla.com/picl/v1/$info'),
        i,
      ]).bytes;
      result.addAll(previous);
    }
    return result.sublist(0, length);
  }

  static String derivePassword(String email, String password) {
    final hmac = Hmac(sha256, utf8.encode(password));
    var block = hmac.convert([
      ...utf8.encode(
        'identity.mozilla.com/picl/v1/quickStretch:${normalizeEmail(email)}',
      ),
      0,
      0,
      0,
      1,
    ]).bytes;
    final stretched = List<int>.of(block);
    for (var i = 1; i < 1000; i++) {
      block = hmac.convert(block).bytes;
      for (var j = 0; j < stretched.length; j++) {
        stretched[j] ^= block[j];
      }
    }
    return _hex(_hkdf(stretched, 'authPW', 32));
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static String hawk(
    String token,
    String endpoint,
    String body, {
    int? timestamp,
    String? nonce,
  }) {
    if (!RegExp(r'^(?:[a-fA-F0-9]{2}){32,128}$').hasMatch(token) ||
        !{'verify', 'oauth'}.contains(endpoint)) {
      throw const MozillaException(MozillaError.auth);
    }
    final material = _hkdf(
      [
        for (var i = 0; i < token.length; i += 2)
          int.parse(token.substring(i, i + 2), radix: 16),
      ],
      'sessionToken',
      64,
    );
    final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final random = Random.secure();
    final n =
        nonce ??
        base64Url
            .encode(List<int>.generate(6, (_) => random.nextInt(256)))
            .replaceAll('=', '');
    final payload = base64.encode(
      sha256
          .convert(utf8.encode('hawk.1.payload\napplication/json\n$body\n'))
          .bytes,
    );
    final url = Uri.parse(endpoints[endpoint]!);
    final normalized =
        'hawk.1.header\n$ts\n$n\nPOST\n${url.path}\n${url.host}\n443\n$payload\n\n';
    final mac = base64.encode(
      Hmac(sha256, material.sublist(32)).convert(utf8.encode(normalized)).bytes,
    );
    return 'Hawk id="${_hex(material.sublist(0, 32))}", ts="$ts", nonce="$n", mac="$mac", hash="$payload"';
  }

  Future<Map<String, dynamic>> login(
    String enteredEmail,
    String password,
  ) async {
    final email = normalizeEmail(enteredEmail);
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email) ||
        email.length > 254 ||
        password.isEmpty ||
        password.length > 4096) {
      throw const MozillaException(MozillaError.credentials);
    }
    final authPW = await Isolate.run(() => derivePassword(email, password));
    var response = await request(
      'login',
      body: jsonEncode({
        'email': email,
        'authPW': authPW,
        'verificationMethod': 'email-2fa',
      }),
    );
    if (response.status == 400 && jsonDecode(response.body)['errno'] == 107) {
      response = await request(
        'login',
        body: jsonEncode({'email': email, 'authPW': authPW}),
      );
    }
    final data = response.json();
    if (data['sessionToken'] is! String) {
      throw const MozillaException(MozillaError.auth);
    }
    return {...data, 'email': email};
  }

  Future<void> verify(String session, String code) async {
    final body = jsonEncode({'code': code.trim()});
    (await request(
      'verify',
      body: body,
      authorization: hawk(session, 'verify', body),
    )).json();
  }

  Future<Map<String, dynamic>> authorize(Map<String, dynamic> session) async {
    final body = jsonEncode({
      'client_id': clientId,
      'grant_type': 'fxa-credentials',
      'scope': scope,
      'access_type': 'offline',
    });
    final data = (await request(
      'oauth',
      body: body,
      authorization: hawk(session['sessionToken'] as String, 'oauth', body),
    )).json();
    return tokens(session['email'] as String, data);
  }

  static Map<String, dynamic> tokens(
    String email,
    Map<String, dynamic> data, {
    String? previousRefresh,
  }) {
    final access = data['access_token'];
    final refresh = data['refresh_token'] ?? previousRefresh;
    for (final value in [access, refresh]) {
      if (value is! String ||
          value.isEmpty ||
          value.length > 16384 ||
          RegExp(r'[\s\x00-\x1f\x7f]').hasMatch(value)) {
        throw const MozillaException(MozillaError.auth);
      }
    }
    return {
      'email': email,
      'accessToken': access,
      'refreshToken': refresh,
      'expiresAt':
          DateTime.now().millisecondsSinceEpoch ~/ 1000 +
          max(60, (data['expires_in'] as num?)?.toInt() ?? 86400),
    };
  }
}
