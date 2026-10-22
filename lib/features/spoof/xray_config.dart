import 'models.dart';

const kSpoofDefaultUdpPort = 40443;
const kSpoofSocksPort = 20808;
const kSpoofHttpPort = 20809;
const kSpoofPortScanStart = 38408;

const kMciPrimaryEdge = '104.18.1.1';
const kMciFallbackEdge = '172.66.0.1';
const kBaseEdge = '104.18.32.47';
const kBaseFallbackEdge = '172.64.155.209';

List<Map<String, dynamic>> iranDirectRules() => [
  {'type': 'field', 'ip': ['geoip:private'], 'outboundTag': 'direct'},
  {
    'type': 'field',
    'domain': ['geosite:category-ir', r'regexp:\.ir$'],
    'outboundTag': 'direct',
  },
  {'type': 'field', 'ip': ['geoip:ir'], 'outboundTag': 'direct'},
];

List<Map<String, dynamic>> buildSpoofInbounds({
  required int socksPort,
  required int httpPort,
  required bool iranDirect,
}) {
  final inbounds = [
    {
      'listen': '127.0.0.1',
      'port': socksPort,
      'protocol': 'socks',
      'tag': 'socks-in',
      'settings': {'auth': 'noauth', 'udp': true, 'ip': '127.0.0.1'},
    },
    {
      'listen': '127.0.0.1',
      'port': httpPort,
      'protocol': 'http',
      'tag': 'http-in',
      'settings': {'allowTransparent': false},
    },
  ];
  if (iranDirect) {
    for (final inbound in inbounds) {
      inbound['sniffing'] = {
        'enabled': true,
        'destOverride': ['http', 'tls'],
        'routeOnly': true,
      };
    }
  }
  return inbounds;
}

Map<String, dynamic> buildProxyOutbound(SpoofProfile profile) {
  final upstream = profile.edge.isNotEmpty && !profile.isReality
      ? profile.edge
      : profile.host;
  final String protocol = profile.protocol;
  Map<String, dynamic> settings;
  switch (protocol) {
    case 'trojan':
      settings = {
        'servers': [
          {
            'address': upstream,
            'port': profile.port,
            'password': profile.authId,
          },
        ],
      };
    case 'vless':
      final user = {'id': profile.authId, 'encryption': profile.encryption};
      settings = {
        'vnext': [
          {'address': upstream, 'port': profile.port, 'users': [user]},
        ],
      };
    case 'vmess':
      settings = {
        'vnext': [
          {
            'address': upstream,
            'port': profile.port,
            'users': [
              {'id': profile.authId, 'alterId': 0, 'security': profile.encryption},
            ],
          },
        ],
      };
    default:
      throw FormatException('unsupported protocol $protocol');
  }
  final stream = <String, dynamic>{};
  var network = profile.network;
  if (network == 'tcp') network = 'raw';
  stream['network'] = network;
  stream['security'] = profile.security;
  final isTls = profile.security == 'tls';
  if (profile.security == 'reality') {
    stream['realitySettings'] = {
      'serverName': profile.sni,
      'fingerprint': profile.fingerprint.isEmpty
          ? 'chrome'
          : profile.fingerprint,
      'publicKey': profile.realityPublicKey,
      'shortId': profile.realityShortId,
      'spiderX': profile.realitySpiderX,
    };
  } else if (isTls) {
    final tls = <String, dynamic>{'serverName': profile.sni};
    if (network == 'ws' || network == 'httpupgrade') {
      tls['alpn'] = ['http/1.1'];
    }
    if (profile.fingerprint.isNotEmpty) {
      tls['fingerprint'] = profile.fingerprint;
    }
    if (profile.sni.toLowerCase() != profile.hostHeader.toLowerCase()) {
      tls['verifyPeerCertByName'] = '${profile.hostHeader},${profile.sni}';
    }
    stream['tlsSettings'] = tls;
  } else {
    stream['sockopt'] = {'domainStrategy': 'UseIPv4'};
  }
  switch (network) {
    case 'httpupgrade':
      stream['httpupgradeSettings'] = {
        'path': profile.path,
        'host': profile.hostHeader,
      };
    case 'ws':
      stream['wsSettings'] = {
        'path': profile.path,
        'host': profile.hostHeader,
        'headers': {'Host': profile.hostHeader},
      };
    case 'grpc':
      final grpc = {'serviceName': profile.serviceName};
      if (profile.mode.isNotEmpty) grpc['authority'] = profile.mode;
      stream['grpcSettings'] = grpc;
    case 'xhttp':
      stream['xhttpSettings'] = {
        'path': profile.path,
        'host': profile.hostHeader,
        if (profile.mode.isNotEmpty) 'mode': profile.mode,
      };
    case 'raw':
      stream['rawSettings'] = {
        'header': {'type': profile.mode.isEmpty ? 'none' : profile.mode},
      };
    default:
      throw FormatException('unsupported transport $network');
  }
  if (profile.hasFragment && !profile.isReality) {
    stream['finalmask'] = {
      'tcp': [
        {
          'type': 'fragment',
          'settings': profile.fragment.toJson(),
        },
      ],
    };
    stream['sockopt'] = {
      'domainStrategy': 'UseIPv4',
      'tcpKeepAliveInterval': 1,
      'tcpKeepAliveIdle': 11,
    };
  }
  final proxyOutbound = {
    'tag': 'proxy',
    'protocol': protocol,
    'settings': settings,
    'streamSettings': stream,
  };
  if (profile.mux && profile.security != 'reality' && !profile.isReality) {
    proxyOutbound['mux'] = {
      'enabled': true,
      'concurrency': 8,
      'xudpConcurrency': 8,
      'xudpProxyUDP443': 'allow',
    };
  }
  return proxyOutbound;
}

Map<String, dynamic> buildSpoofXrayConfig({
  required SpoofProfile profile,
  int socksPort = kSpoofSocksPort,
  int httpPort = kSpoofHttpPort,
  bool iranDirect = true,
  String logLevel = 'warning',
  List<String> bypassProcesses = const [],
}) {
  final inbounds = buildSpoofInbounds(
    socksPort: socksPort,
    httpPort: httpPort,
    iranDirect: iranDirect,
  );
  final rules = <Map<String, dynamic>>[];
  if (bypassProcesses.isNotEmpty) {
    rules.insert(0, {
      'type': 'field',
      'process': bypassProcesses,
      'outboundTag': 'direct',
    });
  }
  if (iranDirect) rules.addAll(iranDirectRules());
  return {
    'log': {'loglevel': logLevel},
    'inbounds': inbounds,
    'outbounds': [
      buildProxyOutbound(profile),
      {'tag': 'direct', 'protocol': 'freedom'},
      {'tag': 'block', 'protocol': 'blackhole'},
    ],
    'routing': {'domainStrategy': 'AsIs', 'rules': rules},
  };
}
