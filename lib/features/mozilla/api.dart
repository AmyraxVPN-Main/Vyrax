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

typedef _RawExchange =
    ({int status, String body, Map<String, String> headers});

typedef MozillaRequest =
    Future<MozillaResponse> Function(
      String endpoint, {
      String body,
      String authorization,
    });

const String mozillaControlPlaneUserAgent =
    'MozillaVPN/2.35.0 (sys:linux; iap:true)';

class MozillaCookieJar {
  MozillaCookieJar();
  final Map<String, List<({String name, String value, DateTime? expires})>>
  _byDomain = {};
  static final _token = RegExp(r"^[A-Za-z0-9_!#$%&'*+.^-]+$");
  static final _split = RegExp(r",\s*(?=[A-Za-z0-9_!#$%&'*+.^-]+=[^;])");

  void install(String name, String value, String domain, [DateTime? expires]) {
    if (name.isEmpty || !_token.hasMatch(name)) return;
    final bucket = _byDomain.putIfAbsent(domain.toLowerCase(), () => []);
    bucket.removeWhere((cookie) => cookie.name == name);
    bucket.add((name: name, value: value, expires: expires));
  }

  void save(Uri uri, List<String> setCookie) {
    for (final raw in setCookie) {
      for (final segment in raw.split(_split)) {
        final text = segment.trim();
        final first = text.indexOf(';');
        final pair = (first < 0 ? text : text.substring(0, first)).trim();
        final equals = pair.indexOf('=');
        if (equals <= 0) continue;
        final name = pair.substring(0, equals).trim();
        final value = pair.substring(equals + 1).trim();
        var domain = uri.host.toLowerCase();
        DateTime? expires;
        for (final attribute
            in (first < 0 ? '' : text.substring(first + 1)).split(';')) {
          final attributeParts = attribute.split('=');
          final key = attributeParts.first.trim().toLowerCase();
          final setting = attributeParts.skip(1).join('=').trim();
          if (key == 'domain') {
            domain = setting.replaceFirst(RegExp(r'^\.'), '').toLowerCase();
          } else if (key == 'max-age') {
            final seconds = int.tryParse(setting);
            if (seconds != null && seconds > 0) {
              expires = DateTime.now().add(Duration(seconds: seconds));
            }
          } else if (key == 'expires') {
            try {
              expires = HttpDate.parse(setting);
            } on HttpException {
              expires = DateTime.tryParse(setting);
            } catch (_) {}
          }
        }
        install(name, value, domain, expires);
      }
    }
  }

  Map<String, String> cookiesFor(Uri uri) {
    final host = uri.host.toLowerCase();
    final now = DateTime.now();
    final out = <String, String>{};
    for (final entry in _byDomain.entries) {
      if (host != entry.key && !host.endsWith('.${entry.key}')) continue;
      for (final cookie in entry.value) {
        final when = cookie.expires;
        if (when != null && when.isBefore(now)) continue;
        out[cookie.name] = cookie.value;
      }
    }
    return out;
  }

  List<({String name, String value})> snapshot() => [
    for (final list in _byDomain.values)
      for (final cookie in list) (name: cookie.name, value: cookie.value),
  ];

  static final MozillaCookieJar app = MozillaCookieJar();
}

/// Leniently coerces a JSON number that may arrive as int, double or numeric
/// string — mirrors org.json's optLong behavior in FoxyVPN.
int? mozillaJsonNum(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value) ?? double.tryParse(value)?.toInt();
  }
  return null;
}

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

  static const _challengeable = {
    'login',
    'verify',
    'oauth',
    'activate',
    'status',
    'token',
  };

  static Future<_RawExchange> _exchange(
    Uri uri,
    String method, {
    String body = '',
    String authorization = '',
    String? proxy,
    String? userAgent,
    String? accept,
    MozillaCookieJar? cookies,
    String? origin,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..badCertificateCallback = (_, _, _) => false;
    if (proxy != null) client.findProxy = (_) => proxy;
    try {
      final outgoing = await client.openUrl(method, uri);
      outgoing.followRedirects = false;
      outgoing.headers.set(
        HttpHeaders.userAgentHeader,
        userAgent ?? mozillaControlPlaneUserAgent,
      );
      outgoing.headers.set(
        HttpHeaders.acceptHeader,
        accept ?? 'application/json',
      );
      if (origin != null) {
        outgoing.headers.set('origin', origin);
      }
      final jar = cookies;
      if (jar != null) {
        final header = jar
            .cookiesFor(uri)
            .entries
            .map((cookie) => '${cookie.key}=${cookie.value}')
            .join('; ');
        if (header.isNotEmpty) {
          outgoing.headers.set(HttpHeaders.cookieHeader, header);
        }
      }
      if (authorization.isNotEmpty) {
        outgoing.headers.set(HttpHeaders.authorizationHeader, authorization);
      }
      if (method == 'POST') {
        outgoing.headers.contentType = ContentType.json;
      }
      outgoing.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      outgoing.write(body);
      final response = await outgoing.close();
      final bytes = <int>[];
      await for (final chunk in response) {
        if (bytes.length + chunk.length > 1048576) {
          throw const MozillaException(MozillaError.service);
        }
        bytes.addAll(chunk);
      }
      final jarSink = cookies;
      jarSink?.save(uri, response.headers[HttpHeaders.setCookieHeader] ?? []);
      return (
        status: response.statusCode,
        body: utf8.decode(bytes),
        headers: {
          for (final key in [
            'x-quota-limit',
            'x-quota-remaining',
            'x-quota-reset',
          ])
            key: ?response.headers.value(key),
        },
      );
    } on MozillaException {
      rethrow;
    } catch (_) {
      throw const MozillaException(MozillaError.network);
    } finally {
      client.close(force: true);
    }
  }

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
    final method = {'login', 'verify', 'oauth', 'activate'}.contains(endpoint)
        ? 'POST'
        : 'GET';
    var attempts = 0;
    while (true) {
      attempts++;
      final raw = await _exchange(
        Uri.parse(address),
        method,
        body: body,
        authorization: authorization,
        proxy: proxy,
        cookies: MozillaCookieJar.app,
      ).timeout(const Duration(seconds: 20));
      if (raw.status == 406 &&
          _challengeable.contains(endpoint) &&
          attempts < 3) {
        await FastlyChallengeSolver(proxy: proxy).solve();
        continue;
      }
      return MozillaResponse(raw.status, raw.body, raw.headers);
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
          max(60, mozillaJsonNum(data['expires_in']) ?? 86400),
    };
  }
}

class _NoChallenge implements Exception {}

// Fastly service-worker challenge handling, adapted from FoxyVPN
// FastlyChallengeSolver.kt, copyright 2026 Vauth (MIT).
class FastlyChallengeSolver {
  FastlyChallengeSolver({this.proxy});
  final String? proxy;
  static const _solverUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36';
  static const _htmlAccept =
      'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';
  static const _alphabet =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  static final _prefixPattern = RegExp(r'/_fs-ch-[A-Za-z0-9]+');
  static final _initCall = RegExp(
    r'init\((\[[^\]]*\]),\s*"([^"]+)",\s*"([^"]+)"',
  );
  static const _rounds = 3;

  Future<void> solve() async {
    Object? lastError;
    for (final base in [
      'https://api.accounts.firefox.com',
      'https://accounts.firefox.com',
    ]) {
      try {
        await _solveOnHost(base);
        return;
      } on _NoChallenge {
        continue;
      } on MozillaException catch (error) {
        if (error.reason == MozillaError.network) rethrow;
        lastError = error;
      }
      // Other solver failures fall through to the next host and, if every
      // host failed, surface as the generic challenge error below.
      catch (error) {
        lastError = error;
      }
    }
    if (lastError is MozillaException &&
        lastError.reason != MozillaError.challenge) {
      throw lastError;
    }
    throw const MozillaException(MozillaError.challenge);
  }

  Future<_RawExchange> _fetch(
    String url, {
    String method = 'GET',
    String body = '',
    String accept = _htmlAccept,
    String? origin,
    MozillaCookieJar? jar,
  }) async =>
      MozillaApi._exchange(
        Uri.parse(url),
        method,
        body: body,
        proxy: proxy,
        userAgent: _solverUserAgent,
        accept: accept,
        cookies: jar,
        origin: origin,
      );

  bool _isChallenge(String body) =>
      body.contains('/_fs-ch-') && body.contains('Client Challenge');

  Future<void> _solveOnHost(String base) async {
    final jar = MozillaCookieJar();
    final page = await _fetch('$base/', jar: jar);
    if (page.status != 200 || !_isChallenge(page.body)) {
      if (page.status == 200) throw _NoChallenge();
      throw const MozillaException(MozillaError.challenge);
    }
    final prefixMatch = _prefixPattern.firstMatch(page.body);
    if (prefixMatch == null) {
      throw const MozillaException(MozillaError.challenge);
    }
    final prefix = base + prefixMatch.group(0)!;
    final script = await _fetch('$prefix/script.js?reload=true', jar: jar);
    if (script.status != 200) {
      throw const MozillaException(MozillaError.challenge);
    }
    final calls = _initCall.allMatches(script.body).toList();
    if (calls.isEmpty) throw const MozillaException(MozillaError.challenge);
    final call = calls.last;
    var challenges = jsonDecode(call.group(1)!) as List;
    var token = call.group(2)!;
    if (challenges.isEmpty || token.isEmpty) {
      throw const MozillaException(MozillaError.challenge);
    }
    for (var round = 0; round < _rounds; round++) {
      final answers = <Map<String, dynamic>>[];
      for (final challenge in challenges) {
        if (challenge is! Map) {
          throw const MozillaException(MozillaError.challenge);
        }
        answers.add(await _answer(base, prefix, token, challenge));
      }
      final postBack = await _fetch(
        '$prefix/fst-post-back',
        method: 'POST',
        body: jsonEncode({'token': token, 'data': answers}),
        accept: 'application/json',
        origin: base,
        jar: jar,
      );
      if (postBack.status != 200) {
        throw const MozillaException(MozillaError.challenge);
      }
      final data = jsonDecode(postBack.body);
      if (data is Map && data['status'] == 'success') {
        final verified = await _fetch('$base/', jar: jar);
        if (verified.status != 200 || _isChallenge(verified.body)) {
          throw const MozillaException(MozillaError.challenge);
        }
        final issued = jar.snapshot();
        if (issued.isEmpty) {
          throw const MozillaException(MozillaError.challenge);
        }
        for (final cookie in issued) {
          MozillaCookieJar.app.install(cookie.name, cookie.value, 'firefox.com');
        }
        return;
      }
      if (data is! Map ||
          data['ch'] is! List ||
          (data['ch'] as List).isEmpty ||
          data['tok'] is! String ||
          (data['tok'] as String).isEmpty) {
        throw const MozillaException(MozillaError.challenge);
      }
      challenges = data['ch'] as List;
      token = data['tok'] as String;
    }
    throw const MozillaException(MozillaError.challenge);
  }

  Future<Map<String, dynamic>> _answer(
    String base,
    String prefix,
    String token,
    Map challenge,
  ) async {
    final data = challenge['data'] is Map
        ? challenge['data'] as Map
        : const <String, dynamic>{};
    return switch (challenge['ty']?.toString()) {
      'pow' => () {
        final baseText = data['base']?.toString() ?? '';
        final answer = _solvePoW(baseText, data['hash']?.toString() ?? '');
        if (answer == null) throw const MozillaException(MozillaError.challenge);
        return <String, dynamic>{
          'ty': 'pow',
          'base': baseText,
          'answer': answer,
          'hmac': data['hmac']?.toString() ?? '',
          'expires': data['expires']?.toString() ?? '',
        };
      }(),
      'pat' => <String, dynamic>{'ty': 'pat', 'auth': await _pat(prefix, token)},
      'clientmetrics' => _clientMetricsAnswer(),
      _ => throw const MozillaException(MozillaError.challenge),
    };
  }

  Future<String> _pat(String prefix, String token) async {
    final response = await _fetch(
      '$prefix/pat?token=${Uri.encodeQueryComponent(token)}',
      method: 'POST',
      accept: 'text/plain',
      origin: prefix.substring(0, prefix.indexOf('/_fs-ch-')),
    );
    if (response.status == 400 || response.status == 401) return '';
    if (response.status != 200) {
      throw const MozillaException(MozillaError.challenge);
    }
    final data = jsonDecode(response.body);
    final auth = data is Map ? data['auth']?.toString() ?? '' : '';
    if (auth.isEmpty) throw const MozillaException(MozillaError.challenge);
    return auth;
  }

  Map<String, dynamic> _clientMetricsAnswer() => <String, dynamic>{
    'ty': 'clientmetrics',
    'webdriver': false,
    'bot_detection_result': {'bot_detected': false, 'bot_kind': null},
    'browser_metrics': {'client_data': '{}', 'error_trace': null},
    'detector_results': <String, dynamic>{},
    'v': 2,
  };

  String? _solvePoW(String base, String targetHex) {
    if (targetHex.length != 64) return null;
    final target = <int>[];
    try {
      for (var i = 0; i < 32; i++) {
        target.add(int.parse(targetHex.substring(i * 2, i * 2 + 2), radix: 16));
      }
    } catch (_) {
      return null;
    }
    for (final a in _alphabet.codeUnits) {
      for (final b in _alphabet.codeUnits) {
        final suffix = String.fromCharCodes([a, b]);
        final digest = sha256.convert(utf8.encode('$base$suffix')).bytes;
        var matched = digest.length == target.length;
        for (var i = 0; matched && i < digest.length; i++) {
          if (digest[i] != target[i]) matched = false;
        }
        if (matched) return suffix;
      }
    }
    return null;
  }
}
