import 'dart:convert';

class SpoofShareLinkException implements Exception {
  const SpoofShareLinkException(this.reason);
  final String reason;
}

enum SpoofFragmentStrategy {
  plain,
  full5,
  full10,
  full20,
  multi64,
  gfwFirst,
}

extension SpoofFragmentStrategyName on SpoofFragmentStrategy {
  String get name => switch (this) {
    SpoofFragmentStrategy.plain => 'plain',
    SpoofFragmentStrategy.full5 => 'full5',
    SpoofFragmentStrategy.full10 => 'full10',
    SpoofFragmentStrategy.full20 => 'full20',
    SpoofFragmentStrategy.multi64 => 'multi64',
    SpoofFragmentStrategy.gfwFirst => 'gfw_first',
  };

  static SpoofFragmentStrategy fromName(String value) =>
      SpoofFragmentStrategy.values.firstWhere(
        (strategy) => strategy.name == value,
        orElse: () => SpoofFragmentStrategy.full5,
      );
}

enum SpoofCarrier { auto, mci, irancell }

extension SpoofCarrierName on SpoofCarrier {
  String get name => switch (this) {
    SpoofCarrier.auto => 'auto',
    SpoofCarrier.mci => 'mci',
    SpoofCarrier.irancell => 'irancell',
  };

  static SpoofCarrier fromName(String value) => SpoofCarrier.values.firstWhere(
    (carrier) => carrier.name == value,
    orElse: () => SpoofCarrier.auto,
  );
}

class SpoofFragmentSettings {
  final String packets;
  final String length;
  final String delay;
  final String maxSplit;

  const SpoofFragmentSettings({
    this.packets = 'tlshello',
    this.length = '',
    this.delay = '0-0',
    this.maxSplit = '0',
  });

  bool get hasFragment => length.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'packets': packets,
    'length': length,
    'delay': delay,
    if (maxSplit != '0') 'maxSplit': maxSplit,
  };

  static String _string(dynamic value) => value == null ? '' : '$value'.trim();

  factory SpoofFragmentSettings.fromJson(Map<String, dynamic> json) =>
      SpoofFragmentSettings(
        packets: json['packets'] ?? 'tlshello',
        length: _string(json['length']),
        delay: _string(json['delay']).isEmpty ? '0-0' : _string(json['delay']),
        maxSplit: json['maxSplit'] ?? '0',
      );

  static const full5 = SpoofFragmentSettings(
    packets: 'tlshello',
    length: '5-5',
    delay: '5-5',
  );

  static const full10 = SpoofFragmentSettings(
    packets: 'tlshello',
    length: '10-10',
    delay: '2-2',
  );

  static const full20 = SpoofFragmentSettings(
    packets: 'tlshello',
    length: '20-20',
    delay: '1-1',
  );

  static const multi64 = SpoofFragmentSettings(
    packets: 'tlshello',
    length: '64-64',
    delay: '0-0',
  );

  static const gfwFirst = SpoofFragmentSettings(
    packets: 'tlshello',
    length: '1-3',
    delay: '0-0',
    maxSplit: '2-2',
  );

  static SpoofFragmentSettings forStrategy(SpoofFragmentStrategy strategy) =>
      switch (strategy) {
        SpoofFragmentStrategy.plain => full5,
        SpoofFragmentStrategy.full5 => full5,
        SpoofFragmentStrategy.full10 => full10,
        SpoofFragmentStrategy.full20 => full20,
        SpoofFragmentStrategy.multi64 => multi64,
        SpoofFragmentStrategy.gfwFirst => gfwFirst,
      };

  SpoofFragmentSettings copyWith({String? length, String? delay}) =>
      SpoofFragmentSettings(
        packets: packets,
        length: length ?? this.length,
        delay: delay ?? this.delay,
        maxSplit: maxSplit,
      );
}

class SpoofProfile {
  final String id;
  final String label;
  final String sourceUri;
  final String protocol;
  final String host;
  final int port;
  final String authId;
  final String encryption;
  final String security;
  final String network;
  final String sni;
  final String hostHeader;
  final String path;
  final String serviceName;
  final String mode;
  final String fingerprint;
  final String realityPublicKey;
  final String realityShortId;
  final String realitySpiderX;
  final String edge;
  final SpoofFragmentSettings fragment;
  final bool mux;
  final String countryCode;
  final int lastProbeMs;
  final DateTime? lastProbeAt;

  const SpoofProfile({
    required this.id,
    required this.label,
    required this.sourceUri,
    required this.protocol,
    required this.host,
    required this.port,
    required this.authId,
    required this.encryption,
    required this.security,
    required this.network,
    required this.sni,
    required this.hostHeader,
    required this.path,
    required this.serviceName,
    required this.mode,
    required this.fingerprint,
    required this.realityPublicKey,
    required this.realityShortId,
    required this.realitySpiderX,
    required this.edge,
    required this.fragment,
    required this.mux,
    required this.countryCode,
    this.lastProbeMs = 0,
    this.lastProbeAt,
  });

  bool get isReality => security == 'reality';

  bool get hasFragment => fragment.hasFragment;

  String get displayLabel => label.isEmpty ? '$host:$port' : label;

  SpoofProfile copyWith({
    String? label,
    String? edge,
    SpoofFragmentSettings? fragment,
    bool? mux,
    String? countryCode,
    int? lastProbeMs,
    DateTime? lastProbeAt,
  }) => SpoofProfile(
    id: id,
    label: label ?? this.label,
    sourceUri: sourceUri,
    protocol: protocol,
    host: host,
    port: port,
    authId: authId,
    encryption: encryption,
    security: security,
    network: network,
    sni: sni,
    hostHeader: hostHeader,
    path: path,
    serviceName: serviceName,
    mode: mode,
    fingerprint: fingerprint,
    realityPublicKey: realityPublicKey,
    realityShortId: realityShortId,
    realitySpiderX: realitySpiderX,
    edge: edge ?? this.edge,
    fragment: fragment ?? this.fragment,
    mux: mux ?? this.mux,
    countryCode: countryCode ?? this.countryCode,
    lastProbeMs: lastProbeMs ?? this.lastProbeMs,
    lastProbeAt: lastProbeAt ?? this.lastProbeAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'sourceUri': sourceUri,
    'protocol': protocol,
    'host': host,
    'port': port,
    'authId': authId,
    'encryption': encryption,
    'security': security,
    'network': network,
    'sni': sni,
    'hostHeader': hostHeader,
    'path': path,
    'serviceName': serviceName,
    'mode': mode,
    'fingerprint': fingerprint,
    'realityPublicKey': realityPublicKey,
    'realityShortId': realityShortId,
    'realitySpiderX': realitySpiderX,
    'edge': edge,
    'fragment': fragment.toJson(),
    'mux': mux,
    'countryCode': countryCode,
    if (lastProbeMs > 0) 'lastProbeMs': lastProbeMs,
    if (lastProbeAt != null) 'lastProbeAt': lastProbeAt!.millisecondsSinceEpoch,
  };

  factory SpoofProfile.fromJson(Map<String, dynamic> json) => SpoofProfile(
    id: json['id'],
    label: json['label'],
    sourceUri: json['sourceUri'] ?? '',
    protocol: json['protocol'],
    host: json['host'],
    port: json['port'],
    authId: json['authId'],
    encryption: json['encryption'] ?? 'none',
    security: json['security'],
    network: json['network'],
    sni: json['sni'] ?? '',
    hostHeader: json['hostHeader'] ?? '',
    path: json['path'] ?? '',
    serviceName: json['serviceName'] ?? '',
    mode: json['mode'] ?? '',
    fingerprint: json['fingerprint'] ?? '',
    realityPublicKey: json['realityPublicKey'] ?? '',
    realityShortId: json['realityShortId'] ?? '',
    realitySpiderX: json['realitySpiderX'] ?? '',
    edge: json['edge'] ?? '',
    fragment: SpoofFragmentSettings.fromJson(
      (json['fragment'] ?? const {}) as Map<String, dynamic>,
    ),
    mux: json['mux'] ?? false,
    countryCode: json['countryCode'] ?? '',
    lastProbeMs: json['lastProbeMs'] ?? 0,
    lastProbeAt: json['lastProbeAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['lastProbeAt'])
        : null,
  );
}

class SpoofBundle {
  final String id;
  final List<SpoofProfile> servers;
  final DateTime? createdAt;

  const SpoofBundle({required this.id, required this.servers, this.createdAt});

  bool get isEmpty => servers.isEmpty;

  String get label {
    if (servers.isEmpty) return '';
    final first = servers.first.displayLabel;
    if (servers.length == 1) return first;
    return '$first +${servers.length - 1}';
  }

  SpoofBundle copyWith({List<SpoofProfile>? servers}) => SpoofBundle(
    id: id,
    servers: servers ?? this.servers,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'servers': [for (final server in servers) server.toJson()],
    if (createdAt != null) 'createdAt': createdAt!.millisecondsSinceEpoch,
  };

  factory SpoofBundle.fromJson(Map<String, dynamic> json) => SpoofBundle(
    id: json['id'],
    servers: [
      for (final item in ((json['servers'] ?? const []) as List).whereType<Map>())
        SpoofProfile.fromJson(Map<String, dynamic>.from(item)),
    ],
    createdAt: json['createdAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
        : null,
  );
}

int _stableHash(String value) {
  var hash = 5381;
  for (final code in value.codeUnits) {
    hash = ((hash << 5) + hash + code) & 0x7fffffff;
  }
  return hash;
}

String _decodeTitle(String source) {
  final sharp = source.indexOf('#');
  if (sharp < 0) return '';
  return Uri.decodeFull(source.substring(sharp + 1)).replaceFirst(
    RegExp(r'\s+$'),
    '',
  );
}

SpoofProfile parseSpoofShareLink(String source, {String countryCode = ''}) {
  final input = source.trim();
  final lower = input.toLowerCase();
  if (lower.startsWith('vmess://')) {
    return _parseVmess(input, countryCode: countryCode);
  }
  final scheme = lower.startsWith('vless://')
      ? 'vless'
      : lower.startsWith('trojan://')
      ? 'trojan'
      : '';
  if (scheme.isEmpty) {
    throw const SpoofShareLinkException('scheme');
  }
  final uri = Uri.tryParse(input);
  if (uri == null || uri.host.isEmpty) {
    throw const SpoofShareLinkException('uri');
  }
  final authId = uri.userInfo;
  if (authId.isEmpty) {
    throw SpoofShareLinkException(scheme);
  }
  final params = uri.queryParameters;
  String one(String key) => (params[key] ?? '').trim();
  var network = one('type').toLowerCase();
  if (network == 'tcp') network = 'raw';
  if (network.isEmpty) network = 'raw';
  var security = one('security').toLowerCase();
  if (security.isEmpty && one('tls') == '1') security = 'tls';
  if (security != 'reality' && one('pbk').isNotEmpty) security = 'reality';
  var sni = one('sni').isEmpty ? one('peer') : one('sni');
  var hostHeader = one('host').isEmpty ? one('servername') : one('host');
  final port = uri.port;
  if (port == 0) throw const SpoofShareLinkException('port');
  if (hostHeader.isEmpty) hostHeader = uri.host;
  if (security.isNotEmpty && sni.isEmpty) sni = hostHeader;
  final label = _decodeTitle(input);
  return SpoofProfile(
    id: 'spoof-$scheme-${_stableHash('$authId@${uri.host}:$port${one('path')}')}',
    label: label,
    sourceUri: input,
    protocol: scheme,
    host: uri.host,
    port: port,
    authId: authId,
    encryption: one('encryption').isEmpty ? 'none' : one('encryption'),
    security: security,
    network: network,
    sni: sni,
    hostHeader: hostHeader,
    path: one('path'),
    serviceName: one('serviceName'),
    mode: one('mode'),
    fingerprint: one('fp'),
    realityPublicKey: one('pbk'),
    realityShortId: one('sid'),
    realitySpiderX: one('spx'),
    edge: '',
    fragment: const SpoofFragmentSettings(),
    mux: false,
    countryCode: countryCode,
  );
}

SpoofProfile _parseVmess(String source, {required String countryCode}) {
  final text = Uri.decodeFull(source).replaceFirst(RegExp('vmess://'), '');
  final json = jsonDecode(
    utf8.decode(base64.decode(base64.normalize(text))),
  );
  if (json is! Map<String, dynamic>) {
    throw const SpoofShareLinkException('vmess-json');
  }
  final host = '${json['add'] ?? ''}'.trim();
  final port = int.tryParse('${json['port'] ?? ''}') ?? 0;
  if (host.isEmpty || port == 0) {
    throw const SpoofShareLinkException('vmess-address');
  }
  final id = '${json['id'] ?? ''}'.trim();
  if (id.isEmpty) throw const SpoofShareLinkException('vmess-id');
  var network = '${json['net'] ?? ''}'.toLowerCase();
  if (network == 'tcp') network = 'raw';
  if (network.isEmpty) network = 'raw';
  final isTls = '${json['tls'] ?? ''}' == 'tls';
  var hostHeader = '${json['host'] ?? ''}'.trim();
  if (hostHeader.isEmpty) hostHeader = host;
  return SpoofProfile(
    id: 'spoof-vmess-${_stableHash('$id@$host:$port')}',
    label: '${json['ps'] ?? ''}'.trim(),
    sourceUri: source,
    protocol: 'vmess',
    host: host,
    port: port,
    authId: id,
    encryption: '${json['scy'] ?? 'auto'}'.trim(),
    security: isTls ? 'tls' : '',
    network: network,
    sni: '${json['sni'] ?? ''}'.trim(),
    hostHeader: hostHeader,
    path: '${json['path'] ?? ''}'.trim(),
    serviceName: '',
    mode: '',
    fingerprint: '${json['fp'] ?? ''}'.trim(),
    realityPublicKey: '',
    realityShortId: '',
    realitySpiderX: '',
    edge: '',
    fragment: const SpoofFragmentSettings(),
    mux: false,
    countryCode: countryCode,
  );
}
