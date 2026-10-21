import 'dart:convert';
import 'dart:typed_data';

class ForeignProfileException implements Exception {
  const ForeignProfileException(this.format, this.node);
  final String format;
  final int node;
}

Uint8List convertForeignProfile(Uint8List bytes) {
  var text = utf8
      .decode(bytes, allowMalformed: true)
      .replaceFirst(RegExp(r'^\uFEFF'), '')
      .trim();
  if (!text.startsWith('{') && !text.startsWith('[')) {
    try {
      final decoded = base64.decode(
        base64.normalize(text.replaceAll(RegExp(r'\s'), '')),
      );
      text = utf8.decode(decoded).trim();
      bytes = Uint8List.fromList(decoded);
    } on FormatException {
      return bytes;
    }
    if (!text.startsWith('{') && !text.startsWith('[')) return bytes;
  }
  dynamic data;
  try {
    data = jsonDecode(_jsonWithoutComments(text));
  } on FormatException {
    return bytes;
  }
  if (data is Map && !data.containsKey('outbounds')) {
    if (!data.containsKey('server_port') && !data.containsKey('protocol')) {
      return bytes;
    }
  } else if (data is! List && data is! Map) {
    return bytes;
  }
  if (data is List &&
      !data.any(
        (item) =>
            item is Map &&
            (item.containsKey('server_port') ||
                item.containsKey('protocol') ||
                item.containsKey('outbounds')),
      )) {
    return bytes;
  }
  var converter = _ForeignConverter();
  try {
    if (text.length > 4 * 1024 * 1024) throw const FormatException();
    final roots =
        data is List &&
            data.any((item) => item is Map && item.containsKey('outbounds'))
        ? data
        : [
            data is List ? {'outbounds': data} : data,
          ];
    final proxies = <Map<String, dynamic>>[];
    final groups = <Map<String, dynamic>>[];
    for (final root in roots) {
      final previous = converter;
      converter = _ForeignConverter()
        ..names.addAll(previous.names)
        ..node = previous.node;
      final value = _object(root);
      final outbounds = value['outbounds'];
      if (outbounds != null && outbounds is! List) {
        throw const FormatException();
      }
      final items = outbounds is List ? outbounds : [value];
      if (items.isEmpty || converter.node + items.length > 10000) {
        throw const FormatException();
      }
      for (final item in items) {
        converter.node++;
        final node = _object(item);
        if (node.containsKey('protocol')) {
          converter.format = 'Xray';
          converter.xray(node);
        } else {
          converter.format = 'sing-box';
          converter.singBox(node);
        }
      }
      converter.finish();
      proxies.addAll(converter.proxies);
      groups.addAll(converter.groups);
    }
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'proxies': proxies,
          if (groups.isNotEmpty) 'proxy-groups': groups,
        }),
      ),
    );
  } catch (_) {
    throw ForeignProfileException(converter.format, converter.node);
  }
}

String _jsonWithoutComments(String input) {
  final output = StringBuffer();
  var quoted = false;
  var escaped = false;
  for (var i = 0; i < input.length; i++) {
    final c = input[i];
    if (quoted) {
      output.write(c);
      if (escaped) {
        escaped = false;
      } else if (c == r'\') {
        escaped = true;
      } else if (c == '"') {
        quoted = false;
      }
    } else if (c == '"') {
      quoted = true;
      output.write(c);
    } else if (c == '/' && i + 1 < input.length && input[i + 1] == '/') {
      while (i + 1 < input.length && input[i + 1] != '\n') {
        i++;
      }
      output.write(' ');
    } else if (c == '/' && i + 1 < input.length && input[i + 1] == '*') {
      final end = input.indexOf('*/', i + 2);
      if (end < 0) throw const FormatException();
      i = end + 1;
      output.write(' ');
    } else {
      output.write(c);
    }
  }
  final clean = output.toString();
  final result = StringBuffer();
  quoted = false;
  escaped = false;
  for (var i = 0; i < clean.length; i++) {
    final c = clean[i];
    if (!quoted && c == ',') {
      var next = i + 1;
      while (next < clean.length && clean[next].trim().isEmpty) {
        next++;
      }
      if (next < clean.length && (clean[next] == '}' || clean[next] == ']')) {
        continue;
      }
    }
    result.write(c);
    if (escaped) {
      escaped = false;
    } else if (quoted && c == r'\') {
      escaped = true;
    } else if (c == '"') {
      quoted = !quoted;
    }
  }
  return result.toString();
}

Map<String, dynamic> _object(dynamic value) {
  if (value == null) return {};
  if (value is! Map<String, dynamic>) throw const FormatException();
  return value;
}

void _keys(Map<String, dynamic> value, Set<String> allowed) {
  if (value.keys.any((key) => !allowed.contains(key))) {
    throw const FormatException();
  }
}

dynamic _single(dynamic value) {
  if (value is! List || value.length != 1) throw const FormatException();
  return value.single;
}

class _ForeignConverter {
  String format = 'Xray / sing-box';
  int node = 0;
  final proxies = <Map<String, dynamic>>[];
  final groups = <Map<String, dynamic>>[];
  final names = <String>{'DIRECT', 'REJECT', 'COMPATIBLE'};
  final tags = <String, String>{};

  String name(dynamic tag) {
    if (tag != null && tag is! String) throw const FormatException();
    final raw = tag as String?;
    if (raw != null && raw.isNotEmpty && tags.containsKey(raw)) {
      throw const FormatException();
    }
    final base = raw == null || raw.isEmpty ? '$format $node' : raw;
    var result = base;
    var i = 2;
    while (!names.add(result)) {
      result = '$base ($i)';
      i++;
    }
    if (raw != null && raw.isNotEmpty) tags[raw] = result;
    return result;
  }

  void copy(
    Map<String, dynamic> source,
    Map<String, dynamic> target,
    Map<String, String> fields,
  ) {
    for (final entry in fields.entries) {
      if (source[entry.key] != null) target[entry.value] = source[entry.key];
    }
  }

  Map<String, dynamic> endpoint(
    String type,
    String name,
    dynamic host,
    dynamic port,
  ) {
    final number = port is int ? port : int.tryParse('$port');
    if (host is! String ||
        host.isEmpty ||
        number == null ||
        number < 1 ||
        number > 65535) {
      throw const FormatException();
    }
    return {'name': name, 'type': type, 'server': host, 'port': number};
  }

  void singBox(Map<String, dynamic> value) {
    final type = value['type'];
    final tag = value['tag'];
    if (type == 'direct' || type == 'block') {
      _keys(value, {'type', 'tag'});
      final key = name(tag);
      if (tag is String && tag.isNotEmpty) {
        tags[tag] = type == 'direct' ? 'DIRECT' : 'REJECT';
      }
      names.remove(key);
      return;
    }
    if (type == 'selector' || type == 'urltest') {
      _keys(value, {
        'type',
        'tag',
        'outbounds',
        'default',
        'interrupt_exist_connections',
        'url',
        'interval',
        'tolerance',
      });
      if (value['interrupt_exist_connections'] == true) {
        throw const FormatException();
      }
      final group = <String, dynamic>{
        'name': name(tag),
        'type': type == 'selector' ? 'select' : 'url-test',
        'proxies': value['outbounds'],
      };
      if (type == 'urltest') {
        group['url'] = value['url'] ?? 'https://www.gstatic.com/generate_204';
        final interval = value['interval'] ?? '3m';
        final match = RegExp(r'^(\d+)(s|m|h)$').firstMatch('$interval');
        if (match == null) throw const FormatException();
        group['interval'] =
            int.parse(match[1]!) *
            switch (match[2]) {
              'm' => 60,
              'h' => 3600,
              _ => 1,
            };
        copy(value, group, {'tolerance': 'tolerance'});
      }
      if (value['default'] != null) group['_default'] = value['default'];
      groups.add(group);
      return;
    }
    if (!{
      'vless',
      'vmess',
      'trojan',
      'shadowsocks',
      'hysteria2',
      'tuic',
      'http',
      'socks',
    }.contains(type)) {
      throw const FormatException();
    }
    _keys(value, {
      'type',
      'tag',
      'server',
      'server_port',
      'uuid',
      'password',
      'method',
      'security',
      'alter_id',
      'flow',
      'tls',
      'transport',
      'detour',
      'username',
      'version',
      'obfs',
      'up_mbps',
      'down_mbps',
      'congestion_control',
      'udp_relay_mode',
      'zero_rtt_handshake',
    });
    final proxy = endpoint(
      switch (type) {
        'shadowsocks' => 'ss',
        'socks' => 'socks5',
        _ => type as String,
      },
      name(tag),
      value['server'],
      value['server_port'],
    );
    if (type == 'socks' &&
        value['version'] != null &&
        value['version'] != '5') {
      throw const FormatException();
    }
    copy(value, proxy, {
      'uuid': 'uuid',
      'password': 'password',
      'method': 'cipher',
      'security': 'cipher',
      'alter_id': 'alterId',
      'flow': 'flow',
      'username': 'username',
      'detour': 'dialer-proxy',
      'up_mbps': 'up',
      'down_mbps': 'down',
      'congestion_control': 'congestion-controller',
      'udp_relay_mode': 'udp-relay-mode',
      'zero_rtt_handshake': 'reduce-rtt',
    });
    if (type == 'vmess') {
      proxy['cipher'] ??= 'auto';
      proxy['alterId'] ??= 0;
    }
    if (type == 'hysteria2' && value['obfs'] != null) {
      final obfs = _object(value['obfs']);
      _keys(obfs, {'type', 'password'});
      proxy['obfs'] = obfs['type'];
      proxy['obfs-password'] = obfs['password'];
    }
    singTls(_object(value['tls']), proxy);
    if (type == 'trojan') proxy['skip-tls'] = proxy['tls'] != true;
    if ({'hysteria2', 'tuic'}.contains(type) && proxy['tls'] != true) {
      throw const FormatException();
    }
    transport(_object(value['transport']), proxy, xray: false);
    proxies.add(proxy);
  }

  void singTls(Map<String, dynamic> tls, Map<String, dynamic> proxy) {
    _keys(tls, {
      'enabled',
      'server_name',
      'insecure',
      'alpn',
      'utls',
      'reality',
    });
    if (tls.isEmpty) return;
    if (tls['enabled'] != null && tls['enabled'] is! bool) {
      throw const FormatException();
    }
    if (proxy['type'] == 'ss') throw const FormatException();
    if ({'http', 'socks5'}.contains(proxy['type']) &&
        tls.keys.any(
          (key) => !{'enabled', 'server_name', 'insecure'}.contains(key),
        )) {
      throw const FormatException();
    }
    final enabled = tls['enabled'] == true;
    proxy['tls'] = enabled;
    if (!enabled && tls.keys.any((key) => key != 'enabled')) {
      throw const FormatException();
    }
    copy(tls, proxy, {
      'server_name': proxy['type'] == 'vmess' || proxy['type'] == 'vless'
          ? 'servername'
          : 'sni',
      'insecure': 'skip-cert-verify',
      'alpn': 'alpn',
    });
    final utls = _object(tls['utls']);
    _keys(utls, {'enabled', 'fingerprint'});
    if (utls['enabled'] == true) {
      proxy['client-fingerprint'] = utls['fingerprint'] ?? 'chrome';
    }
    final reality = _object(tls['reality']);
    _keys(reality, {'enabled', 'public_key', 'short_id'});
    if (reality['enabled'] == true) {
      if (!enabled) throw const FormatException();
      if (reality['public_key'] is! String ||
          (reality['public_key'] as String).isEmpty) {
        throw const FormatException();
      }
      proxy['reality-opts'] = {
        'public-key': reality['public_key'],
        'short-id': reality['short_id'] ?? '',
      };
      proxy['client-fingerprint'] ??= 'chrome';
    }
  }

  void xray(Map<String, dynamic> value) {
    final type = value['protocol'];
    final tag = value['tag'];
    if (type == 'freedom' || type == 'blackhole') {
      _keys(value, {'protocol', 'tag', 'settings'});
      if (_object(value['settings']).isNotEmpty) throw const FormatException();
      final key = name(tag);
      if (tag is String && tag.isNotEmpty) {
        tags[tag] = type == 'freedom' ? 'DIRECT' : 'REJECT';
      }
      names.remove(key);
      return;
    }
    _keys(value, {
      'protocol',
      'tag',
      'settings',
      'streamSettings',
      'mux',
      'proxySettings',
    });
    if (!{
      'vless',
      'vmess',
      'trojan',
      'shadowsocks',
      'socks',
      'http',
    }.contains(type)) {
      throw const FormatException();
    }
    final mux = _object(value['mux']);
    _keys(mux, {'enabled', 'concurrency'});
    if (mux['enabled'] == true) throw const FormatException();
    final settings = _object(value['settings']);
    _keys(settings, {'vnext', 'servers'});
    final isV = type == 'vmess' || type == 'vless';
    final server = _object(_single(settings[isV ? 'vnext' : 'servers']));
    _keys(server, {
      'address',
      'port',
      'users',
      'password',
      'method',
      'email',
      'ota',
      'level',
    });
    if (server['ota'] == true) throw const FormatException();
    final proxy = endpoint(
      switch (type) {
        'shadowsocks' => 'ss',
        'socks' => 'socks5',
        _ => type as String,
      },
      name(tag),
      server['address'],
      server['port'],
    );
    if (isV) {
      final user = _object(_single(server['users']));
      _keys(user, {
        'id',
        'alterId',
        'security',
        'encryption',
        'flow',
        'email',
        'level',
      });
      if (type == 'vless' &&
          user['encryption'] != null &&
          user['encryption'] != 'none') {
        throw const FormatException();
      }
      copy(user, proxy, {'id': 'uuid', 'flow': 'flow'});
      if (type == 'vmess') {
        proxy['cipher'] = user['security'] ?? 'auto';
        proxy['alterId'] = user['alterId'] ?? 0;
      }
    } else {
      copy(server, proxy, {'password': 'password', 'method': 'cipher'});
      if (server['users'] != null) {
        final user = _object(_single(server['users']));
        _keys(user, {'user', 'pass'});
        copy(user, proxy, {'user': 'username', 'pass': 'password'});
      }
    }
    final chain = _object(value['proxySettings']);
    _keys(chain, {'tag', 'transportLayer'});
    if (chain['transportLayer'] == true) throw const FormatException();
    if (chain['tag'] != null) proxy['dialer-proxy'] = chain['tag'];
    final stream = _object(value['streamSettings']);
    _keys(stream, {
      'network',
      'security',
      'tlsSettings',
      'realitySettings',
      'wsSettings',
      'grpcSettings',
      'httpupgradeSettings',
      'xhttpSettings',
      'tcpSettings',
    });
    final security = stream['security'] ?? 'none';
    if (type == 'trojan') proxy['skip-tls'] = security == 'none';
    if (!{'none', 'tls', 'reality'}.contains(security)) {
      throw const FormatException();
    }
    if (type == 'shadowsocks' && security != 'none') {
      throw const FormatException();
    }
    if ({'http', 'socks'}.contains(type) &&
        security != 'none' &&
        (security != 'tls' ||
            _object(stream['tlsSettings']).keys.any(
              (key) => !{'serverName', 'allowInsecure'}.contains(key),
            ))) {
      throw const FormatException();
    }
    proxy['tls'] = security != 'none';
    if (security != 'none') {
      final tls = _object(
        stream[security == 'reality' ? 'realitySettings' : 'tlsSettings'],
      );
      _keys(tls, {
        'serverName',
        'allowInsecure',
        'alpn',
        'fingerprint',
        'publicKey',
        'password',
        'shortId',
        'show',
      });
      copy(tls, proxy, {
        'serverName': isV ? 'servername' : 'sni',
        'allowInsecure': 'skip-cert-verify',
        'alpn': 'alpn',
        'fingerprint': 'client-fingerprint',
      });
      if (security == 'reality') {
        final key = tls['publicKey'] ?? tls['password'];
        if (key is! String || key.isEmpty) throw const FormatException();
        proxy['reality-opts'] = {
          'public-key': key,
          'short-id': tls['shortId'] ?? '',
        };
        proxy['client-fingerprint'] ??= 'chrome';
      }
    }
    final network = stream['network'] ?? 'tcp';
    final options = _object(stream['${network}Settings']);
    transport({'type': network, ...options}, proxy, xray: true);
    proxies.add(proxy);
  }

  void transport(
    Map<String, dynamic> value,
    Map<String, dynamic> proxy, {
    required bool xray,
  }) {
    final type = value['type'] ?? 'tcp';
    if (type == 'tcp') {
      _keys(value, {'type', 'header'});
      final header = _object(value['header']);
      if (header.isNotEmpty &&
          (header.length != 1 || header['type'] != 'none')) {
        throw const FormatException();
      }
      return;
    }
    if (!{'vmess', 'vless', 'trojan'}.contains(proxy['type'])) {
      throw const FormatException();
    }
    if (type == 'ws' || type == 'httpupgrade') {
      _keys(value, {
        'type',
        'path',
        'headers',
        'host',
        'max_early_data',
        'early_data_header_name',
      });
      final headers = _object(value['headers']);
      proxy['network'] = 'ws';
      proxy['ws-opts'] = {
        'path': value['path'] ?? '/',
        if (headers.isNotEmpty || value['host'] != null)
          'headers': {
            ...headers,
            if (value['host'] != null) 'Host': value['host'],
          },
        if (value['max_early_data'] != null)
          'max-early-data': value['max_early_data'],
        if (value['early_data_header_name'] != null)
          'early-data-header-name': value['early_data_header_name'],
        if (type == 'httpupgrade') 'v2ray-http-upgrade': true,
      };
    } else if (type == 'grpc') {
      _keys(value, {'type', 'serviceName', 'service_name', 'multiMode'});
      if (value['multiMode'] == true) throw const FormatException();
      proxy['network'] = 'grpc';
      proxy['grpc-opts'] = {
        'grpc-service-name': value[xray ? 'serviceName' : 'service_name'] ?? '',
      };
    } else if (type == 'xhttp' && xray && proxy['type'] == 'vless') {
      _keys(value, {'type', 'path', 'host', 'mode', 'extra'});
      proxy['network'] = 'xhttp';
      final options = <String, dynamic>{
        'path': value['path'] ?? '/',
        'host': value['host'] ?? '',
        'mode': value['mode'] ?? 'auto',
      };
      final extra = _object(value['extra']);
      const fields = {
        'headers': 'headers',
        'noGRPCHeader': 'no-grpc-header',
        'xPaddingBytes': 'x-padding-bytes',
        'xPaddingObfsMode': 'x-padding-obfs-mode',
        'xPaddingKey': 'x-padding-key',
        'xPaddingHeader': 'x-padding-header',
        'xPaddingPlacement': 'x-padding-placement',
        'xPaddingMethod': 'x-padding-method',
        'uplinkHTTPMethod': 'uplink-http-method',
        'sessionPlacement': 'session-placement',
        'sessionKey': 'session-key',
        'sessionTable': 'session-table',
        'sessionLength': 'session-length',
        'seqPlacement': 'seq-placement',
        'seqKey': 'seq-key',
        'uplinkDataPlacement': 'uplink-data-placement',
        'uplinkDataKey': 'uplink-data-key',
        'uplinkChunkSize': 'uplink-chunk-size',
        'scMaxEachPostBytes': 'sc-max-each-post-bytes',
        'scMinPostsIntervalMs': 'sc-min-posts-interval-ms',
      };
      _keys(extra, {...fields.keys, 'xmux'});
      copy(extra, options, fields);
      if (extra['xmux'] != null) {
        final reuse = _object(extra['xmux']);
        const reuseFields = {
          'maxConcurrency': 'max-concurrency',
          'maxConnections': 'max-connections',
          'cMaxReuseTimes': 'c-max-reuse-times',
          'hMaxRequestTimes': 'h-max-request-times',
          'hMaxReusableSecs': 'h-max-reusable-secs',
          'hKeepAlivePeriod': 'h-keep-alive-period',
        };
        _keys(reuse, reuseFields.keys.toSet());
        final converted = <String, dynamic>{};
        copy(reuse, converted, reuseFields);
        options['reuse-settings'] = converted;
      }
      proxy['xhttp-opts'] = options;
    } else {
      throw const FormatException();
    }
  }

  Map<String, dynamic> finish() {
    if (proxies.isEmpty) throw const FormatException();
    for (final proxy in proxies) {
      final chain = proxy['dialer-proxy'];
      if (chain != null) {
        final resolved = tags[chain];
        if (resolved == null || resolved == proxy['name']) {
          throw const FormatException();
        }
        proxy['dialer-proxy'] = resolved;
      }
    }
    for (final group in groups) {
      final members = group['proxies'];
      if (members is! List || members.isEmpty) throw const FormatException();
      group['proxies'] = members.map((tag) {
        final result = tags[tag];
        if (result == null || result == group['name']) {
          throw const FormatException();
        }
        return result;
      }).toList();
      final preferred = group.remove('_default');
      if (preferred != null) {
        final resolved = tags[preferred];
        final list = group['proxies'] as List;
        if (resolved == null || !list.remove(resolved)) {
          throw const FormatException();
        }
        list.insert(0, resolved);
      }
    }
    final graph = <String, List<String>>{
      for (final proxy in proxies)
        proxy['name'] as String: [
          if (proxy['dialer-proxy'] case final String chain) chain,
        ],
      for (final group in groups)
        group['name'] as String: List<String>.from(group['proxies'] as List),
    };
    final colors = <String, int>{};
    for (final root in graph.keys) {
      if (colors[root] == 2) continue;
      colors[root] = 1;
      final stack = <(String, Iterator<String>)>[(root, graph[root]!.iterator)];
      while (stack.isNotEmpty) {
        final top = stack.last;
        if (!top.$2.moveNext()) {
          colors[top.$1] = 2;
          stack.removeLast();
          continue;
        }
        final next = top.$2.current;
        if (colors[next] == 1) throw const FormatException();
        if (colors[next] == 2 || !graph.containsKey(next)) continue;
        colors[next] = 1;
        stack.add((next, graph[next]!.iterator));
      }
    }
    return {'proxies': proxies, if (groups.isNotEmpty) 'proxy-groups': groups};
  }
}
