import 'dart:convert';

/// Converts plain share-link lists (`vless://`, `vmess://`, `ss://`,
/// `trojan://`, `hysteria2://`, `tuic://`, `wireguard://`) — the format
/// most free-server lists ship in — into mihomo `proxies` maps.
/// Returns null when the text is not a share-link list.
List<Map<String, dynamic>>? parseShareLinkList(String text) {
  final lines = text
      .split(RegExp(r'[\r\n]+'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toList();
  if (lines.isEmpty) return null;
  const schemes = [
    'vless://',
    'vmess://',
    'ss://',
    'trojan://',
    'hysteria2://',
    'hy2://',
    'tuic://',
    'wireguard://',
    'wg://',
  ];
  var links = 0;
  var other = 0;
  for (final line in lines) {
    if (schemes.any(line.toLowerCase().startsWith)) {
      links++;
    } else {
      other++;
    }
  }
  if (links == 0 || other > links) return null;
  final proxies = <Map<String, dynamic>>[];
  final names = <String>{};
  for (final line in lines) {
    final proxy = _parseLink(line);
    if (proxy == null) continue;
    var name = (proxy['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) {
      name = '${proxy['type']}-${proxy['server']}-${proxy['port']}';
    }
    var unique = name;
    var index = 2;
    while (!names.add(unique)) {
      unique = '$name ${index++}';
    }
    proxy['name'] = unique;
    proxies.add(proxy);
    if (proxies.length >= 2000) break;
  }
  if (proxies.isEmpty) return null;
  return proxies;
}

Map<String, dynamic>? _parseLink(String link) {
  final schemeEnd = link.indexOf('://');
  if (schemeEnd <= 0) return null;
  final scheme = link.substring(0, schemeEnd).toLowerCase();
  final body = link.substring(schemeEnd + 3);
  final hash = body.indexOf('#');
  final label = hash >= 0
      ? Uri.decodeComponent(body.substring(hash + 1)).trim()
      : '';
  final main = hash >= 0 ? body.substring(0, hash) : body;
  final queryIndex = main.indexOf('?');
  final query = queryIndex >= 0
      ? Uri.splitQueryString(main.substring(queryIndex + 1))
      : <String, String>{};
  final authority = queryIndex >= 0 ? main.substring(0, queryIndex) : main;
  try {
    return switch (scheme) {
      'vmess' => _vmess(authority, query, label),
      'vless' => _vless(authority, query, label),
      'trojan' => _trojan(authority, query, label),
      'ss' => _ss(authority, label),
      'hysteria2' || 'hy2' => _hysteria2(authority, query, label),
      'tuic' => _tuic(authority, query, label),
      'wireguard' || 'wg' => _wireguard(authority, query, label),
      _ => null,
    };
  } on FormatException {
    return null;
  }
}

({String host, int port, String userInfo}) _authority(
  String authority,
  int defaultPort,
) {
  var rest = authority;
  String userInfo = '';
  final at = rest.lastIndexOf('@');
  if (at >= 0) {
    userInfo = Uri.decodeComponent(rest.substring(0, at));
    rest = rest.substring(at + 1);
  }
  String host;
  int port = defaultPort;
  if (rest.startsWith('[')) {
    final close = rest.indexOf(']');
    if (close < 0) throw const FormatException();
    host = rest.substring(1, close);
    if (rest.length > close + 2 && rest[close + 1] == ':') {
      port = int.parse(rest.substring(close + 2));
    }
  } else {
    final colon = rest.lastIndexOf(':');
    if (colon >= 0) {
      host = rest.substring(0, colon);
      port = int.parse(rest.substring(colon + 1));
    } else {
      host = rest;
    }
  }
  if (host.isEmpty || port <= 0 || port > 65535) {
    throw const FormatException();
  }
  return (host: host, port: port, userInfo: userInfo);
}

String? _sni(Map<String, String> query) {
  final sni = query['sni'] ?? query['peer'] ?? '';
  return sni.isEmpty ? null : sni;
}

bool? _insecure(Map<String, String> query) {
  final value = (query['allowInsecure'] ?? query['insecure'] ?? '').toLowerCase();
  if (value == '1' || value == 'true') return true;
  return null;
}

Map<String, dynamic>? _vmess(
  String authority,
  Map<String, String> query,
  String label,
) {
  Map<String, dynamic> fields;
  try {
    final decoded = jsonDecode(
      utf8.decode(base64.decode(base64.normalize(authority))),
    );
    if (decoded is! Map<String, dynamic>) return null;
    fields = decoded;
  } on FormatException {
    return null;
  }
  final server = '${fields['add'] ?? ''}'.trim();
  final port = int.tryParse('${fields['port'] ?? ''}');
  final uuid = '${fields['id'] ?? ''}'.trim();
  if (server.isEmpty || port == null || uuid.isEmpty) return null;
  final network = '${fields['net'] ?? 'tcp'}'.trim();
  final proxy = {
    'type': 'vmess',
    'server': server,
    'port': port,
    'uuid': uuid,
    'alterId': int.tryParse('${fields['aid'] ?? 0}') ?? 0,
    'cipher': ('${fields['scy'] ?? fields['security'] ?? 'auto'}').trim(),
    'udp': true,
  };
  if (label.isNotEmpty) proxy['name'] = label;
  final tls = '${fields['tls'] ?? ''}'.toLowerCase() == 'tls';
  if (tls) proxy['tls'] = true;
  final sni = '${fields['sni'] ?? fields['host'] ?? ''}'.trim();
  if (tls && sni.isNotEmpty) proxy['servername'] = sni;
  if (network == 'ws') {
    proxy['network'] = 'ws';
    proxy['ws-opts'] = {
      'path': '${fields['path'] ?? '/'}',
      if ((fields['host'] ?? '').isNotEmpty)
        'headers': {'Host': fields['host']},
    };
  } else if (network == 'grpc') {
    proxy['network'] = 'grpc';
    proxy['grpc-opts'] = {'grpc-service-name': '${fields['path'] ?? ''}'};
  }
  return proxy;
}

Map<String, dynamic>? _vless(
  String authority,
  Map<String, String> query,
  String label,
) {
  final target = _authority(authority, 443);
  if (target.userInfo.isEmpty) return null;
  final proxy = {
    'type': 'vless',
    'server': target.host,
    'port': target.port,
    'uuid': target.userInfo,
    'udp': true,
  };
  if (label.isNotEmpty) proxy['name'] = label;
  final security = (query['security'] ?? 'tls').toLowerCase();
  if (security == 'tls' || security == 'reality') {
    proxy['tls'] = true;
    final sni = _sni(query);
    if (sni != null) proxy['servername'] = sni;
    if (security == 'reality') {
      proxy['reality-opts'] = {
        if (query['pbk']?.isNotEmpty ?? false) 'public-key': query['pbk'],
        if (query['sid']?.isNotEmpty ?? false) 'short-id': query['sid'],
      };
    }
  }
  final flow = query['flow'];
  if (flow?.isNotEmpty ?? false) proxy['flow'] = flow!;
  final network = (query['type'] ?? 'tcp').toLowerCase();
  if (network == 'ws') {
    proxy['network'] = 'ws';
    proxy['ws-opts'] = {
      'path': query['path'] ?? '/',
      if (query['host']?.isNotEmpty ?? false)
        'headers': {'Host': query['host']},
    };
  } else if (network == 'grpc') {
    proxy['network'] = 'grpc';
    proxy['grpc-opts'] = {'grpc-service-name': query['serviceName'] ?? ''};
  }
  return proxy;
}

Map<String, dynamic>? _trojan(
  String authority,
  Map<String, String> query,
  String label,
) {
  final target = _authority(authority, 443);
  if (target.userInfo.isEmpty) return null;
  final proxy = {
    'type': 'trojan',
    'server': target.host,
    'port': target.port,
    'password': target.userInfo,
    'udp': true,
  };
  if (label.isNotEmpty) proxy['name'] = label;
  final sni = _sni(query);
  if (sni != null) proxy['sni'] = sni;
  final insecure = _insecure(query);
  if (insecure != null) proxy['skip-cert-verify'] = insecure;
  return proxy;
}

Map<String, dynamic>? _ss(String authority, String label) {
  String userInfo;
  String rest = authority;
  final at = rest.lastIndexOf('@');
  if (at >= 0) {
    userInfo = rest.substring(0, at);
    rest = rest.substring(at + 1);
  } else {
    // Legacy form: the whole method:password@host:port is base64.
    String decoded;
    try {
      decoded = utf8.decode(base64.decode(base64.normalize(rest)));
    } on FormatException {
      return null;
    }
    final decodedAt = decoded.lastIndexOf('@');
    if (decodedAt < 0) return null;
    userInfo = decoded.substring(0, decodedAt);
    rest = decoded.substring(decodedAt + 1);
  }
  String method;
  String password;
  final colon = userInfo.indexOf(':');
  if (colon >= 0) {
    method = Uri.decodeComponent(userInfo.substring(0, colon));
    password = Uri.decodeComponent(userInfo.substring(colon + 1));
  } else {
    String plain;
    try {
      plain = utf8.decode(base64.decode(base64.normalize(userInfo)));
    } on FormatException {
      return null;
    }
    final plainColon = plain.indexOf(':');
    if (plainColon < 0) return null;
    method = plain.substring(0, plainColon);
    password = plain.substring(plainColon + 1);
  }
  final target = _authority(rest, 443);
  if (method.isEmpty || password.isEmpty) return null;
  final proxy = {
    'type': 'ss',
    'server': target.host,
    'port': target.port,
    'cipher': method,
    'password': password,
    'udp': true,
  };
  if (label.isNotEmpty) proxy['name'] = label;
  return proxy;
}

Map<String, dynamic>? _hysteria2(
  String authority,
  Map<String, String> query,
  String label,
) {
  final target = _authority(authority, 443);
  final proxy = {
    'type': 'hysteria2',
    'server': target.host,
    'port': target.port,
    if (target.userInfo.isNotEmpty) 'password': target.userInfo,
    'udp': true,
  };
  if (label.isNotEmpty) proxy['name'] = label;
  final sni = _sni(query);
  if (sni != null) proxy['sni'] = sni;
  final insecure = _insecure(query);
  if (insecure != null) proxy['skip-cert-verify'] = insecure;
  return proxy;
}

Map<String, dynamic>? _tuic(
  String authority,
  Map<String, String> query,
  String label,
) {
  final target = _authority(authority, 443);
  String uuid = '';
  String password = '';
  final colon = target.userInfo.indexOf(':');
  if (colon >= 0) {
    uuid = target.userInfo.substring(0, colon);
    password = target.userInfo.substring(colon + 1);
  } else {
    uuid = target.userInfo;
  }
  if (uuid.isEmpty) return null;
  final proxy = {
    'type': 'tuic',
    'server': target.host,
    'port': target.port,
    'uuid': uuid,
    if (password.isNotEmpty) 'password': password,
    'udp': true,
  };
  if (label.isNotEmpty) proxy['name'] = label;
  final sni = _sni(query);
  if (sni != null) proxy['sni'] = sni;
  final congestion = query['congestion_control'] ?? query['congestionControl'];
  if (congestion?.isNotEmpty ?? false) {
    proxy['congestion-controller'] = congestion!;
  }
  final insecure = _insecure(query);
  if (insecure != null) proxy['skip-cert-verify'] = insecure;
  return proxy;
}

Map<String, dynamic>? _wireguard(
  String authority,
  Map<String, String> query,
  String label,
) {
  final target = _authority(authority, 51820);
  if (target.userInfo.isEmpty) return null;
  final publicKey = query['publicKey'] ?? query['public-key'] ?? '';
  if (publicKey.isEmpty) return null;
  final proxy = {
    'type': 'wireguard',
    'server': target.host,
    'port': target.port,
    'private-key': target.userInfo,
    'public-key': publicKey,
    'udp': true,
  };
  if (label.isNotEmpty) proxy['name'] = label;
  final preSharedKey = query['preshared-key'] ?? query['pre-shared-key'];
  if (preSharedKey?.isNotEmpty ?? false) {
    proxy['pre-shared-key'] = preSharedKey!;
  }
  final addresses = (query['address'] ?? query['ip'] ?? '')
      .split(',')
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toList();
  if (addresses.isNotEmpty) proxy['ip'] = addresses.first;
  final mtu = int.tryParse(query['mtu'] ?? '');
  if (mtu != null && mtu > 0) proxy['mtu'] = mtu;
  final dns = query['dns'];
  if (dns?.isNotEmpty ?? false) proxy['dns'] = dns!;
  return proxy;
}
