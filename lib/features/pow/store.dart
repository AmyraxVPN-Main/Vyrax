import 'dart:convert';
import 'dart:io';

import 'models.dart';

/// A remembered last-connect record (desktop `LastConnect`).
class PowLastConnect {
  const PowLastConnect({
    this.protocol = '',
    this.transport = '',
    this.ip = '',
    this.peer = '',
    this.throughPsiphon = true,
    this.region = '',
  });

  final String protocol;
  final String transport;
  final String ip;
  final String peer;
  final bool throughPsiphon;
  final String region;
}

/// A user-managed Vyrax Free server entry (location slot).
class PowServerRow {
  const PowServerRow({required this.id, required this.region});

  final String id;
  final String region;

  Map<String, Object?> toJson() => {'id': id, 'region': region};

  static PowServerRow fromJson(Map<Object?, Object?> raw) {
    return PowServerRow(
      id: '${raw['id'] ?? ''}',
      region: normalizeRegion('${raw['region'] ?? ''}'),
    );
  }
}

/// Per-network learned memory row (desktop `learned_networks`).
class PowNetworkRow {
  const PowNetworkRow(this.key, this.seen, this.region);

  final String key;
  final int seen;
  final String region;
}

/// PoW settings persistence — a JSON file under the app data dir
/// (mobile `PowEngineStore` / desktop `pow/store.py` analogue).
class PowStore {
  PowStore(Directory dataDir)
      : path = File(
          '${dataDir.path}${Platform.pathSeparator}$_settingsFilename',
        ) {
    _doc = _read();
    _migrate();
  }

  static const _settingsFilename = 'pow_settings.json';
  static const settingsVersion = 2;
  static const _maxNetworks = 32;

  final File path;

  static const _keyMap = <String, (String, Object?)>{
    'exitCountryCode': ('exit_country', ''),
    'outerTransport': ('outer_transport', outerAuto),
    'obfuscationProfile': ('obfuscation_profile', 'balanced'),
    'h2Fragmentation': ('h2_fragmentation', false),
    'scanMode': ('scan_mode', scanBalanced),
    'optimizedMode': ('optimized_mode', true),
    'firewallProfile': ('firewall_profile', firewallAuto),
    'linkRecipe': ('link_recipe', recipeAuto),
    'chainPsiphon': ('chain_psiphon', true),
    'keyFetch': ('key_fetch', defaultKeyFetch),
    'parallelMasque': ('speed_parallel_masque', false),
    'irancellH3': ('speed_irancell_h3', false),
    'directPsiphonFirst': ('speed_direct_psiphon_first', false),
    'lowestRttIp': ('speed_lowest_rtt_ip', false),
  };

  late final Map<String, Object?> _doc;

  Map<String, Object?> _read() {
    try {
      final raw = path.readAsStringSync();
      final decoded = json.decode(raw);
      if (decoded is Map<String, Object?>) return decoded;
    } on Exception {
      // fall through to empty doc
    }
    return {};
  }

  void _write() {
    path.parent.createSync(recursive: true);
    final tmp = File('${path.path}.tmp');
    try {
      tmp.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(_doc),
      );
      if (tmp.existsSync()) {
        tmp.renameSync(path.path);
      } else {
        tmp.copySync(path.path);
      }
    } on FileSystemException {
      // persistence is best-effort
    } finally {
      try {
        if (tmp.existsSync()) {
          tmp.deleteSync();
        }
      } on FileSystemException {
        // ignore
      }
    }
  }

  void _migrate() {
    var version = 1;
    final rawVersion = _doc['settings_version'];
    if (rawVersion is num) version = rawVersion.toInt();
    if (version >= settingsVersion) return;
    if (_doc.isEmpty) return;
    final fetch = '${_doc['key_fetch'] ?? ''}'.trim().toLowerCase();
    if (fetch.isEmpty || fetch == keyEch) {
      _doc['key_fetch'] = defaultKeyFetch;
    }
    _doc['settings_version'] = settingsVersion;
    try {
      _write();
    } on FileSystemException {
      // ignore
    }
  }

  PowSettings snapshot() {
    final values = <String, Object?>{};
    _keyMap.forEach((attr, record) {
      final (key, default_) = record;
      values[attr] = _doc[key] ?? default_;
    });
    return PowSettings(
      exitCountryCode: '${values['exitCountryCode'] ?? ''}',
      outerTransport: '${values['outerTransport'] ?? outerAuto}',
      obfuscationProfile: '${values['obfuscationProfile'] ?? 'balanced'}',
      h2Fragmentation: values['h2Fragmentation'] == true,
      scanMode: '${values['scanMode'] ?? scanBalanced}',
      optimizedMode: values['optimizedMode'] != false,
      firewallProfile: '${values['firewallProfile'] ?? firewallAuto}',
      linkRecipe: '${values['linkRecipe'] ?? recipeAuto}',
      chainPsiphon: values['chainPsiphon'] != false,
      keyFetch: '${values['keyFetch'] ?? defaultKeyFetch}',
      parallelMasque: values['parallelMasque'] == true,
      irancellH3: values['irancellH3'] == true,
      directPsiphonFirst: values['directPsiphonFirst'] == true,
      lowestRttIp: values['lowestRttIp'] == true,
    ).validated();
  }

  PowSettings save(PowSettings settings) {
    final validated = settings.validated();
    _doc['exit_country'] = validated.exitCountryCode;
    _doc['outer_transport'] = validated.outerTransport;
    _doc['obfuscation_profile'] = validated.obfuscationProfile;
    _doc['h2_fragmentation'] = validated.h2Fragmentation;
    _doc['scan_mode'] = validated.scanMode;
    _doc['optimized_mode'] = validated.optimizedMode;
    _doc['firewall_profile'] = validated.firewallProfile;
    _doc['link_recipe'] = validated.linkRecipe;
    _doc['chain_psiphon'] = validated.chainPsiphon;
    _doc['key_fetch'] = validated.keyFetch;
    _doc['speed_parallel_masque'] = validated.parallelMasque;
    _doc['speed_irancell_h3'] = validated.irancellH3;
    _doc['speed_direct_psiphon_first'] = validated.directPsiphonFirst;
    _doc['speed_lowest_rtt_ip'] = validated.lowestRttIp;
    _doc['settings_version'] = settingsVersion;
    _write();
    return validated;
  }

  void saveLastConnect(PowLastConnect last) {
    _doc['last_connect_protocol'] = last.protocol;
    _doc['last_connect_transport'] = last.transport;
    _doc['last_connect_ip'] = last.ip;
    _doc['last_connect_peer'] = last.peer;
    _doc['last_connect_psiphon'] = last.throughPsiphon;
    _doc['last_connect_region'] = last.region;
    _write();
  }

  PowLastConnect readLastConnect() {
    return PowLastConnect(
      protocol: '${_doc['last_connect_protocol'] ?? ''}',
      transport: '${_doc['last_connect_transport'] ?? ''}',
      ip: '${_doc['last_connect_ip'] ?? ''}',
      peer: '${_doc['last_connect_peer'] ?? ''}',
      throughPsiphon: _doc['last_connect_psiphon'] != false,
      region: normalizeRegion('${_doc['last_connect_region'] ?? ''}'),
    );
  }

  /// Persists just the exit region once the Psiphon notice lands, so the
  /// last-connect record kept the region even when it arrived late.
  void saveLastConnectRegion(String region) {
    final clean = normalizeRegion(region);
    if (clean.isEmpty) return;
    _doc['last_connect_region'] = clean;
    _write();
  }

  int rememberedStrategyIndex(int ladderSize, String shape) {
    if ('${_doc['strategy_shape'] ?? ''}' != shape) {
      _doc['strategy_shape'] = shape;
      _doc['strategy_index'] = 0;
      _write();
      return 0;
    }
    final raw = _doc['strategy_index'];
    final index = raw is num ? raw.toInt() : 0;
    return index.clamp(0, ladderSize - 1).toInt();
  }

  void saveStrategyWinner(int index, String shape) {
    _doc['strategy_shape'] = shape;
    _doc['strategy_index'] = index;
    _write();
  }

  Map<String, Object?> _network(String network, {bool create = false}) {
    final networks = _doc['networks'];
    var map =
        networks is Map<String, Object?> ? networks : <String, Object?>{};
    if (networks is! Map<String, Object?>) {
      if (create) {
        map = <String, Object?>{};
        _doc['networks'] = map;
      }
    }
    final existing = map[network];
    var entry = existing is Map<String, Object?> ? existing : null;
    if (entry == null) {
      entry = <String, Object?>{};
      if (create) {
        if (map.length >= _maxNetworks) {
          String? oldestKey;
          var oldestSeen = 0;
          map.forEach((key, value) {
            final seen = value is Map<String, Object?> ? value['seen'] : null;
            final value0 = seen is num ? seen.toInt() : 0;
            if (oldestKey == null || value0 < oldestSeen) {
              oldestKey = key;
              oldestSeen = value0;
            }
          });
          if (oldestKey != null) {
            map.remove(oldestKey);
          }
        }
        map[network] = entry;
      }
    }
    if (create) {
      entry['seen'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    }
    return entry;
  }

  int? networkStrategyIndex(String network, String shape, int ladderSize) {
    final entry = _network(network);
    if ('${entry['strategy_shape'] ?? ''}' != shape) return null;
    final raw = entry['strategy_index'];
    final index = raw is num ? raw.toInt() : null;
    if (index == null) return null;
    if (index < 0 || index >= ladderSize) return null;
    return index;
  }

  void saveNetworkStrategy(String network, String shape, int index) {
    final entry = _network(network, create: true);
    entry['strategy_shape'] = shape;
    entry['strategy_index'] = index;
    _doc['strategy_shape'] = shape;
    _doc['strategy_index'] = index;
    _write();
  }

  Map<String, int> strategyRtts(String network, List<String> keys) {
    final saved = _network(network)['rtt'];
    if (saved is! Map<String, Object?>) return {};
    final out = <String, int>{};
    for (final key in keys) {
      final raw = saved[key];
      final value = raw is num ? raw.toInt() : 0;
      if (value > 0) out[key] = value;
    }
    return out;
  }

  void saveStrategyRtt(String network, String key, int rttMs) {
    if (rttMs <= 0) return;
    final entry = _network(network, create: true);
    final saved = entry['rtt'];
    entry['rtt'] = saved is Map<String, Object?>
        ? saved
        : <String, Object?>{};
    (entry['rtt'] as Map<String, Object?>)[key] = rttMs;
    _write();
  }

  Map<String, int> cleanPool(String network) {
    final saved = _network(network)['clean_h2'];
    if (saved is! Map<String, Object?>) return {};
    final out = <String, int>{};
    saved.forEach((peer, rtt) {
      final value = rtt is num ? rtt.toInt() : 0;
      out[peer] = value < 0 ? 0 : value;
    });
    return out;
  }

  void saveCleanPool(String network, Map<String, int> pool, [int limit = 12]) {
    final entry = _network(network, create: true);
    final ranked = pool.entries.toList()
      ..sort((a, b) {
        final aOk = a.value > 0;
        final bOk = b.value > 0;
        if (aOk != bOk) return aOk ? -1 : 1;
        return a.value.compareTo(b.value);
      });
    entry['clean_h2'] = {
      for (final row in ranked.take(limit)) row.key: row.value,
    };
    _write();
  }

  String? rememberedRegion(String network) {
    final value = '${_network(network)['region'] ?? ''}'.trim().toUpperCase();
    if (value.isEmpty) return null;
    return value;
  }

  void saveRegion(String network, String code) {
    final clean = code.trim().toUpperCase();
    if (clean.length != 2) return;
    _network(network, create: true)['region'] = clean;
    _write();
  }

  List<PowNetworkRow> learnedNetworks() {
    final networks = _doc['networks'];
    if (networks is! Map<String, Object?>) return [];
    final rows = <PowNetworkRow>[];
    networks.forEach((key, value) {
      if (value is! Map<String, Object?>) return;
      final seen = value['seen'];
      rows.add(
        PowNetworkRow(
          key,
          seen is num ? seen.toInt() : 0,
          '${value['region'] ?? ''}'.trim().toUpperCase(),
        ),
      );
    });
    rows.sort((a, b) => b.seen.compareTo(a.seen));
    return rows;
  }

  String? lastLearnedRegion() {
    for (final row in learnedNetworks()) {
      if (row.region.isNotEmpty) return row.region;
    }
    return null;
  }

  void forgetLearned() {
    _doc.remove('networks');
    _doc.remove('strategy_index');
    _doc.remove('strategy_shape');
    _write();
  }

  String? rememberedOuterProtocol() {
    final value = '${_doc['outer_protocol'] ?? ''}'.trim().toLowerCase();
    if (outerLadder.contains(value)) return value;
    return null;
  }

  void saveOuterProtocol(String protocol) {
    final clean = protocol.trim().toLowerCase();
    if (!outerLadder.contains(clean)) return;
    _doc['outer_protocol'] = clean;
    _write();
  }

  List<String> availableRegions() {
    final raw = '${_doc['available_regions'] ?? ''}';
    return raw
        .split(',')
        .map((part) => part.trim().toUpperCase())
        .where(isRegionCode)
        .toSet()
        .toList()
      ..sort();
  }

  void rememberAvailableRegions(List<String> codes) {
    final clean = codes
        .map((code) => code.trim().toUpperCase())
        .where(isRegionCode)
        .toSet()
        .toList()
      ..sort();
    if (clean.isEmpty) return;
    _doc['available_regions'] = clean.join(',');
    _write();
  }

  static const _maxServers = 20;

  List<PowServerRow> servers() {
    final raw = _doc['servers'];
    final rows = <PowServerRow>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final row = PowServerRow.fromJson(item);
          if (row.id.isNotEmpty) rows.add(row);
        }
      }
    }
    if (rows.isEmpty && _doc['servers'] == null) {
      final defaultRow = PowServerRow(
        id: 's1',
        region: normalizeRegion('${_doc['exit_country'] ?? ''}'),
      );
      _doc['servers'] = [defaultRow.toJson()];
      if ('${_doc['active_server'] ?? ''}' == '') {
        _doc['active_server'] = defaultRow.id;
      }
      _write();
      return [defaultRow];
    }
    return rows;
  }

  String activeServerId() {
    final rows = servers();
    final id = '${_doc['active_server'] ?? ''}';
    if (rows.any((row) => row.id == id)) return id;
    return rows.isEmpty ? '' : rows.first.id;
  }

  PowServerRow? activeServer() {
    final id = activeServerId();
    final rows = servers();
    for (final row in rows) {
      if (row.id == id) return row;
    }
    return rows.isEmpty ? null : rows.first;
  }

  void _saveServers(List<PowServerRow> rows) {
    _doc['servers'] = [for (final row in rows) row.toJson()];
    _write();
  }

  List<PowServerRow> addServer(String region) {
    final rows = servers();
    if (rows.length >= _maxServers) return rows;
    var index = rows.length;
    String id;
    do {
      id = 's${++index}';
    } while (rows.any((row) => row.id == id));
    rows.add(PowServerRow(id: id, region: normalizeRegion(region)));
    _saveServers(rows);
    _doc['active_server'] = id;
    _write();
    return rows;
  }

  List<PowServerRow> setServerRegion(String id, String region) {
    final rows = [
      for (final row in servers())
        row.id == id
            ? PowServerRow(id: id, region: normalizeRegion(region))
            : row,
    ];
    _saveServers(rows);
    return rows;
  }

  List<PowServerRow> removeServer(String id) {
    final rows = servers();
    final next = rows.where((row) => row.id != id).toList();
    if (next.length == rows.length) return rows;
    _saveServers(next);
    if (activeServerId() == id) {
      _doc['active_server'] = next.isEmpty ? '' : next.first.id;
      _write();
    }
    return next;
  }

  void selectServer(String id) {
    final rows = servers();
    if (!rows.any((row) => row.id == id)) return;
    _doc['active_server'] = id;
    _write();
  }

  /// Drops every server slot — the "Vyrax Free" removal flow.
  void clearServers() {
    _doc['servers'] = [];
    _doc['active_server'] = '';
    _write();
  }
}
