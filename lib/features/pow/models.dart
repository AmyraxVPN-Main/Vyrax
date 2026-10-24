/// UAC PoW engine — port of the desktop/mobile pow config
/// (Python `pow/config.py`).
///
/// Chain layout: the `aether` outer leg listens on 1820
/// (WARP / MASQUE / WoW); the Psiphon inner hop listens on 1821 and dials the
/// outer SOCKS.
library;

import 'dart:convert';

const kPowChainSocksPort = 1820;
const kPowPsiphonSocksPort = 1821;
const kPowRouterPort = 1825;

const outerAuto = 'auto';
const outerLadder = ['masque', 'gool', 'wireguard'];
const mciLadder = ['wireguard', 'gool', 'masque'];

const firewallAuto = 'auto';
const firewallIrancell = 'irancell';
const firewallMci = 'mci';
const firewalls = {firewallAuto, firewallIrancell, firewallMci};

const recipeAuto = 'auto';
const recipeWarpV6 = 'warp-v6';
const recipeWarpAny = 'warp-any';
const recipeWowV6 = 'wow-v6';
const recipeWowAny = 'wow-any';
const recipeMasqueH2 = 'masque-h2';
const recipeMasqueH3 = 'masque-h3';
const recipeMasqueH2Split = 'masque-h2-split';
const recipeMasqueH2Saved = 'masque-h2-saved';
const recipes = {
  recipeAuto,
  recipeWarpV6,
  recipeWarpAny,
  recipeWowV6,
  recipeWowAny,
  recipeMasqueH2,
  recipeMasqueH3,
  recipeMasqueH2Split,
  recipeMasqueH2Saved,
};

const keyAuto = 'auto';
const keyEch = 'ech';
const keyFragment = 'fragment';
const keyExternal = 'external';
const keyFetches = {keyAuto, keyEch, keyFragment, keyExternal};

const defaultKeyFetch = keyAuto;
const keyFetchFallback = keyEch;

const keyFetchTimeoutS = 90;
const keyFetchRetryTimeoutS = 60;

const scanTurbo = 'turbo';
const scanBalanced = 'balanced';
const scanThorough = 'thorough';
const scanModes = {scanTurbo, scanBalanced, scanThorough};

const obfuscationProfiles = {'off', 'light', 'balanced', 'aggressive'};

const fronted = [
  'FRONTED-MEEK-OSSH',
  'FRONTED-MEEK-HTTP-OSSH',
  'FRONTED-MEEK-QUIC-OSSH',
];
const fastDirect = ['TLS-OSSH', 'OSSH', 'SSH', 'SHADOWSOCKS-OSSH'];
const chainable = [
  'FRONTED-MEEK-OSSH',
  'FRONTED-MEEK-HTTP-OSSH',
  'TLS-OSSH',
  'UNFRONTED-MEEK-HTTPS-OSSH',
  'UNFRONTED-MEEK-OSSH',
  'SHADOWSOCKS-OSSH',
  'OSSH',
  'SSH',
];
const alternateDns = [
  '208.67.222.222:5353',
  '9.9.9.9:9953',
  '208.67.220.220:5353',
];

const regionPhaseTimeoutSeconds = 25;
const nearbyPhaseTimeoutSeconds = 12;
const chainedLightTimeoutSeconds = 20;
const serverAffinityGraceMs = 1500;

const nearby = [
  'DE', 'NL', 'AT', 'PL', 'CH', 'SE', 'FR', 'GB', 'CZ', 'DK',
  'BE', 'IT', 'RS', 'RO', 'LT', 'FI', 'NO', 'IE', 'ES',
];

const _serverEntrySignaturePublicKey =
    'sHuUVTWaRyh5pZwy4UguSgkwmBe0EHtJJkoF5WrxmvA=';
const _remoteServerListSignaturePublicKey =
    'MIICIDANBgkqhkiG9w0BAQEFAAOCAg0AMIICCAKCAgEAt7Ls+/39r+T6zNW7GiVpJfzq/xvL9SBH5rIFnk0R'
    'XYEYavax3WS6HOD35eTAqn8AniOwiH+DOkvgSKF2caqk/y1dfq47Pdymtwzp9ikpB1C5OfAysXzBiwVJlCd'
    'ajBKvBZDerV1cMvRzCKvKwRmvDmHgphQQ7WfXIGbRbmmk6opMBh3roE42KcotLFtqp0RRwLtcBRNtCdsrVs'
    'jiI1Lqz/lH+T61sGjSjQ3CHMuZYSQJZo/KrvzgQXpkaCTdbObxHqb6/+i1qaVOfEsvjoiyzTxJADvSytVt'
    'cjijhPEV6XskJVHE1Zgl+7rATr/pDQkw6DPCNBS1+Y6fy7GstZALQXwEDN/qhQI9kWkHijT8ns+i1vGg00'
    'Mk/6J75arLhqcodWsdeG/M/moWgqQAnlZAGVtJI1OgeF5fsPpXu4kctOfuZlGjVZXQNW34aOzm8r8S0eV'
    'ZitPlbhcPiR4gT/aSMz/wd8lZlzZYsje/Jr8u/YtlwjjreZrGRmG8KMOzukV3lLmMppXFMvl4bxv6YFEmI'
    'uTsOhbLTwFgh7KYNjodLj/LsqRVfwz31PgWQFTEPICV7GCvgVlPRxnofqKSjgTWI4mxDhBpVcATvaoBl1'
    'L/6WLbFvBsoAUBItWwctO2xalKxF5szhGm8lccoc5MZr8kfE0uxMgsxz4er68iCID+rsCAQM=';
const _exchangeObfuscationKey =
    'DpXzloJk1Hw6aSzmKKky0xcahsEHubch81Mi6K0XMlU=';

const irancellH3BudgetMs = 25000;
const directFastBudgetS = 15;
const mciWgBudgetMs = 20000;

class PowStrategy {
  final String name;
  final String label;
  final int timeoutSeconds;
  final List<String> preferredProtocols;

  const PowStrategy(
    this.name,
    this.label,
    this.timeoutSeconds,
    this.preferredProtocols,
  );
}

const strategyA = PowStrategy(
  'A',
  'domain-fronted (CDN)',
  40,
  fronted,
);
const strategyF = PowStrategy(
  'F',
  'direct through WARP',
  28,
  fastDirect,
);

final List<PowStrategy> strategyLadder = [strategyA, strategyF];

List<PowStrategy> strategyLadderFor(bool direct) {
  if (direct) return List.of(strategyLadder);
  final light = PowStrategy(
    strategyF.name,
    strategyF.label,
    chainedLightTimeoutSeconds,
    strategyF.preferredProtocols,
  );
  return [light, strategyA];
}

String strategySignature(bool? direct) {
  final ladder = strategyLadderFor(direct ?? true);
  return ladder.map((s) => s.name).join(',');
}

String rttKey(bool direct, String strategyName) =>
    (direct ? 'd' : 'c') + strategyName;

int? startIndexOf(
  List<PowStrategy> ladder,
  int? remembered,
  Map<String, int> rttByName,
) {
  final measured = <int>[];
  for (var i = 0; i < ladder.length; i++) {
    final rtt = rttByName[ladder[i].name] ?? 0;
    if (rtt > 0) measured.add(i);
  }
  if (measured.length >= 2) {
    measured.sort((a, b) => (rttByName[ladder[a].name] ?? 0).compareTo(
          rttByName[ladder[b].name] ?? 0,
        ));
    return measured.first;
  }
  if (remembered != null && remembered >= 0 && remembered < ladder.length) {
    return remembered;
  }
  return 0;
}

String? autoBiasRegion(
  String? remembered,
  List<String> available, {
  bool rememberedOnly = false,
}) {
  final live = {
    for (final code in available)
      if (code.trim().length == 2) code.trim().toUpperCase(),
  };
  bool usable(String code) => live.isEmpty || live.contains(code);
  final last = (remembered ?? '').trim().toUpperCase();
  if (nearby.contains(last) && usable(last)) return last;
  if (rememberedOnly) return null;
  for (final code in nearby) {
    if (usable(code)) return code;
  }
  return null;
}

class PowSettings {
  final String exitCountryCode;
  final String outerTransport;
  final String obfuscationProfile;
  final bool h2Fragmentation;
  final String scanMode;
  final bool optimizedMode;
  final String firewallProfile;
  final String linkRecipe;
  final bool chainPsiphon;
  final String keyFetch;
  final bool parallelMasque;
  final bool irancellH3;
  final bool directPsiphonFirst;
  final bool lowestRttIp;

  static const defaultSettings = PowSettings();

  const PowSettings({
    this.exitCountryCode = '',
    this.outerTransport = outerAuto,
    this.obfuscationProfile = 'balanced',
    this.h2Fragmentation = false,
    this.scanMode = scanBalanced,
    this.optimizedMode = true,
    this.firewallProfile = firewallAuto,
    this.linkRecipe = recipeAuto,
    this.chainPsiphon = true,
    this.keyFetch = defaultKeyFetch,
    this.parallelMasque = false,
    this.irancellH3 = false,
    this.directPsiphonFirst = false,
    this.lowestRttIp = false,
  });

  PowSettings copyWith({
    String? exitCountryCode,
    String? outerTransport,
    String? obfuscationProfile,
    bool? h2Fragmentation,
    String? scanMode,
    bool? optimizedMode,
    String? firewallProfile,
    String? linkRecipe,
    bool? chainPsiphon,
    String? keyFetch,
    bool? parallelMasque,
    bool? irancellH3,
    bool? directPsiphonFirst,
    bool? lowestRttIp,
  }) => PowSettings(
        exitCountryCode: exitCountryCode ?? this.exitCountryCode,
        outerTransport: outerTransport ?? this.outerTransport,
        obfuscationProfile: obfuscationProfile ?? this.obfuscationProfile,
        h2Fragmentation: h2Fragmentation ?? this.h2Fragmentation,
        scanMode: scanMode ?? this.scanMode,
        optimizedMode: optimizedMode ?? this.optimizedMode,
        firewallProfile: firewallProfile ?? this.firewallProfile,
        linkRecipe: linkRecipe ?? this.linkRecipe,
        chainPsiphon: chainPsiphon ?? this.chainPsiphon,
        keyFetch: keyFetch ?? this.keyFetch,
        parallelMasque: parallelMasque ?? this.parallelMasque,
        irancellH3: irancellH3 ?? this.irancellH3,
        directPsiphonFirst: directPsiphonFirst ?? this.directPsiphonFirst,
        lowestRttIp: lowestRttIp ?? this.lowestRttIp,
      );

  PowSettings validated() {
    final country = normalizeRegion(exitCountryCode);
    var transport = (outerTransport).trim().toLowerCase();
    if (transport != outerAuto && !outerLadder.contains(transport)) {
      transport = outerAuto;
    }
    var obfuscation = obfuscationProfile.trim().toLowerCase();
    if (!obfuscationProfiles.contains(obfuscation)) obfuscation = 'balanced';
    var firewall = firewallProfile.trim().toLowerCase();
    if (!firewalls.contains(firewall)) firewall = firewallAuto;
    var recipe = linkRecipe.trim().toLowerCase();
    if (!recipes.contains(recipe)) recipe = recipeAuto;
    var fetch = keyFetch.trim().toLowerCase();
    if (!keyFetches.contains(fetch)) fetch = defaultKeyFetch;
    return copyWith(
      exitCountryCode: country,
      outerTransport: transport,
      obfuscationProfile: obfuscation,
      firewallProfile: firewall,
      linkRecipe: recipe,
      keyFetch: fetch,
      scanMode: normalizeScanMode(scanMode),
    );
  }

  Map<String, Object?> toJson() => {
        'exit_country_code': exitCountryCode,
        'outer_transport': outerTransport,
        'obfuscation_profile': obfuscationProfile,
        'h2_fragmentation': h2Fragmentation,
        'scan_mode': scanMode,
        'optimized_mode': optimizedMode,
        'firewall_profile': firewallProfile,
        'link_recipe': linkRecipe,
        'chain_psiphon': chainPsiphon,
        'key_fetch': keyFetch,
        'parallel_masque': parallelMasque,
        'irancell_h3': irancellH3,
        'direct_psiphon_first': directPsiphonFirst,
        'lowest_rtt_ip': lowestRttIp,
      };

  static PowSettings fromJson(Object? json) {
    if (json is! Map<String, Object?>) return defaultSettings;
    String str(String key, String fallback) {
      final value = json[key] ?? fallback;
      return value is String ? value : fallback;
    }

    bool boolOf(String key, bool fallback) {
      final value = json[key] ?? fallback;
      return value is bool ? value : fallback;
    }

    return PowSettings(
      exitCountryCode: str('exit_country_code', ''),
      outerTransport: str('outer_transport', outerAuto),
      obfuscationProfile: str('obfuscation_profile', 'balanced'),
      h2Fragmentation: boolOf('h2_fragmentation', false),
      scanMode: str('scan_mode', scanBalanced),
      optimizedMode: boolOf('optimized_mode', true),
      firewallProfile: str('firewall_profile', firewallAuto),
      linkRecipe: str('link_recipe', recipeAuto),
      chainPsiphon: boolOf('chain_psiphon', true),
      keyFetch: str('key_fetch', defaultKeyFetch),
      parallelMasque: boolOf('parallel_masque', false),
      irancellH3: boolOf('irancell_h3', false),
      directPsiphonFirst: boolOf('direct_psiphon_first', false),
      lowestRttIp: boolOf('lowest_rtt_ip', false),
    );
  }
}

String normalizeScanMode(String? raw) {
  final value = (raw ?? '').trim().toLowerCase();
  if (value == 'fast' || value == scanTurbo) return scanTurbo;
  if (value == 'deep' || value == scanThorough) return scanThorough;
  if (value == scanBalanced) return scanBalanced;
  return scanBalanced;
}

bool usesMciFirewall(PowSettings settings) {
  if (settings.firewallProfile == firewallMci) return true;
  if (settings.firewallProfile == firewallIrancell) return false;
  return true;
}

class PowOuterPlan {
  final List<String> protocols;
  final String ipMode;
  final String masqueTransport;
  final bool fragment;
  final bool fixedOrder;
  final String summary;

  const PowOuterPlan(
    this.protocols,
    this.ipMode,
    this.masqueTransport,
    this.fragment,
    this.fixedOrder,
    this.summary,
  );

  String ipFor(String protocol) {
    if (ipMode == 'v6-warp') {
      return (protocol == 'wireguard' || protocol == 'gool') ? 'v6' : 'v4';
    }
    if (ipMode == 'v6' || ipMode == 'v4' || ipMode == 'both') return ipMode;
    return 'v4';
  }
}

PowOuterPlan outerPlan(PowSettings settings, bool mci) {
  final recipe = settings.validated().linkRecipe;
  switch (recipe) {
    case recipeWarpV6:
      return const PowOuterPlan(['wireguard'], 'v6', 'h3', false, true, 'WARP IPv6');
    case recipeWarpAny:
      return const PowOuterPlan(['wireguard'], 'both', 'h3', false, true, 'WARP any IP');
    case recipeWowV6:
      return const PowOuterPlan(['gool'], 'v6', 'h3', false, true, 'WARP-in-WARP IPv6');
    case recipeWowAny:
      return const PowOuterPlan(['gool'], 'both', 'h3', false, true, 'WARP-in-WARP any IP');
    case recipeMasqueH2:
      return const PowOuterPlan(['masque'], 'both', 'h2', false, true, 'MASQUE HTTP/2');
    case recipeMasqueH3:
      return const PowOuterPlan(['masque'], 'v4', 'h3', false, true, 'MASQUE HTTP/3');
    case recipeMasqueH2Split:
      return const PowOuterPlan(['masque'], 'v4', 'h2', true, true, 'MASQUE HTTP/2 split hello');
    case recipeMasqueH2Saved:
      return const PowOuterPlan(['masque'], 'both', 'h2', false, true, 'MASQUE HTTP/2 saved IPs');
  }
  if (mci) {
    return const PowOuterPlan(['masque'], 'both', 'h2', false, true, 'MASQUE HTTP/2');
  }
  return const PowOuterPlan(outerLadder, 'v4', 'h3', false, false, 'Irancell ladder');
}

List<String> planCandidates(PowSettings settings, bool mci) {
  final mode = settings.outerTransport;
  final ladder = mci ? mciLadder : outerLadder;
  if (mode.isEmpty || mode == outerAuto) return List.of(ladder);
  if (ladder.contains(mode) || outerLadder.contains(mode)) return [mode];
  return List.of(ladder);
}

int outerBudgetMs(
  String protocol, {
  bool retune = false,
  String scanMode = scanBalanced,
}) {
  final mode = normalizeScanMode(scanMode);
  final factor = mode == scanTurbo ? 0.5 : (mode == scanThorough ? 2 : 1);
  final full = switch (protocol) {
    'wireguard' => 33000,
    'gool' => 88000,
    _ => 110000,
  };
  if (retune) return full ~/ 2;
  return (full * factor).round();
}

List<String> keyProtocols(String recipe) {
  switch (recipe) {
    case recipeWowV6:
    case recipeWowAny:
      return ['wireguard', 'gool'];
    case recipeMasqueH2:
    case recipeMasqueH3:
    case recipeMasqueH2Split:
    case recipeMasqueH2Saved:
      return ['masque'];
    case recipeWarpV6:
    case recipeWarpAny:
      return ['wireguard'];
  }
  return ['wireguard', 'gool', 'masque'];
}

String outerLabel(String protocol) =>
    switch (protocol) {
      'masque' => 'MASQUE',
      'wireguard' => 'WireGuard',
      'gool' => 'WoW',
      _ => protocol.toUpperCase(),
    };

const _identityFilename = 'uac-pow.toml';
const _masqueCacheFilename = 'uac-pow-masque-cache.json';
const _settingsFilename = 'pow_settings.json';

String identityPath(String dataDir) => '$dataDir\\$_identityFilename';
String masqueCachePath(String dataDir) => '$dataDir\\$_masqueCacheFilename';
String powSettingsPath(String dataDir) => '$dataDir\\$_settingsFilename';

String chainOuterJson(
  String dataDir,
  String protocol,
  PowSettings settings, {
  String discovery = 'cache',
  String scanMode = scanBalanced,
  bool mci = false,
  String? masqueTransport,
}) {
  final validated = settings.validated();
  final plan = outerPlan(validated, mci);
  final payload = <String, Object?>{
    'config_path': identityPath(dataDir),
    'protocol': protocol,
    'listen': '127.0.0.1:$kPowChainSocksPort',
    'scan_mode': normalizeScanMode(scanMode),
    'ip_scan': plan.ipFor(protocol),
    'endpoint_cache_path': masqueCachePath(dataDir),
    'endpoint_discovery':
        validated.linkRecipe == recipeMasqueH2Saved ? 'clean' : discovery,
    'masque_transport': protocol == 'masque'
        ? (masqueTransport ?? plan.masqueTransport)
        : 'h3',
    'obfuscation_profile': validated.obfuscationProfile,
    'retry_obfuscation_profiles': true,
    'tls_curve_preset': 'chrome',
    'wireguard_data_check': true,
    'log_level': 'info',
    'perf_profile': 'high',
    'h2_fragmentation': plan.fragment && protocol == 'masque',
    'api_camo': validated.keyFetch,
    'gateway': false,
  };
  return json.encode(payload);
}

String keyRequestJson(String dataDir, PowSettings settings, String protocol) {
  final payload = jsonDecode(
    chainOuterJson(
      dataDir,
      protocol,
      settings,
      mci: usesMciFirewall(settings),
    ),
  ) as Map<String, Object?>;
  payload['protocol'] = protocol;
  payload['api_camo'] = settings.validated().keyFetch;
  return json.encode(payload);
}

String certRenewJson(String dataDir, PowSettings settings) {
  final payload =
      jsonDecode(keyRequestJson(dataDir, settings, 'masque')) as Map<String, Object?>;
  payload['renew_masque'] = true;
  return json.encode(payload);
}

String psiphonConfig({
  required int socksPort,
  required String dataDirectory,
  required String? preferredRegion,
  required PowStrategy strategy,
  bool optimizedMode = true,
  bool direct = false,
  bool regionBias = false,
  int upstreamPort = kPowChainSocksPort,
  bool meekOnlyFlag = false,
}) {
  final config = <String, Object?>{
    'PropagationChannelId': 'FFFFFFFFFFFFFFFF',
    'SponsorId': '1111111111111111',
    'EgressRegion': '',
    'EstablishTunnelTimeoutSeconds': strategy.timeoutSeconds,
    'DataDirectory': dataDirectory,
    'ClientVersion': '1',
    'TunnelProtocol': '',
    'RemoteServerListURL': '',
    'LocalSocksProxyPort': socksPort,
    'RemoteServerListSignaturePublicKey': _remoteServerListSignaturePublicKey,
    'ServerEntrySignaturePublicKey': _serverEntrySignaturePublicKey,
    'ExchangeObfuscationKey': _exchangeObfuscationKey,
    'EmitBytesTransferred': true,
    'DeviceRegion': 'IR',
    'ConnectionWorkerPoolSize': optimizedMode ? 12 : 16,
    'EmitDiagnosticNotices': true,
    'DNSResolverPreferredAlternateServers': alternateDns,
    'DNSResolverPreferAlternateServerProbability': optimizedMode ? 1.0 : 0.35,
    'DNSResolverAttemptsPerPreferredServer': optimizedMode ? 2 : 1,
    'InproxyEnabled': false,
    'InproxyAllowClient': false,
    'EstablishTunnelServerAffinityGracePeriodMilliseconds':
        serverAffinityGraceMs,
  };
  if (!direct) {
    config['UpstreamProxyURL'] = 'socks5://127.0.0.1:$upstreamPort';
  }
  List<String>? initial;
  int candidateCount;
  double latency;
  if (strategy.name == 'A') {
    initial = fronted;
    candidateCount = 24;
    latency = 1.5;
    config['ConnectionWorkerPoolSize'] = 12;
  } else {
    initial = fastDirect;
    candidateCount = 16;
    latency = 1.0;
    config['ConnectionWorkerPoolSize'] = 16;
  }
  config['InitialLimitTunnelProtocols'] = initial;
  config['InitialLimitTunnelProtocolsCandidateCount'] = candidateCount;
  config['NetworkLatencyMultiplier'] = latency;
  config['EstablishTunnelTimeoutSeconds'] = strategy.timeoutSeconds;
  if (preferredRegion != null) {
    final region = egressRegion(preferredRegion);
    if (region != null) {
      config['EgressRegion'] = region;
      if (regionBias) {
        config['EstablishTunnelTimeoutSeconds'] = nearbyPhaseTimeoutSeconds;
      } else {
        config['EstablishTunnelTimeoutSeconds'] = regionPhaseTimeoutSeconds;
        config.remove('InitialLimitTunnelProtocols');
        config.remove('InitialLimitTunnelProtocolsCandidateCount');
        config.remove('LimitTunnelProtocols');
      }
    }
  }
  if (direct) {
    final meekOnly = strategy.preferredProtocols.isNotEmpty &&
        strategy.preferredProtocols.every((p) => p.startsWith('FRONTED-'));
    final protocols = meekOnly
        ? ['FRONTED-MEEK-OSSH', 'FRONTED-MEEK-HTTP-OSSH']
        : ['TLS-OSSH', 'SHADOWSOCKS-OSSH'];
    config['LimitTunnelProtocols'] = protocols;
    config['InitialLimitTunnelProtocols'] = protocols;
    config['InitialLimitTunnelProtocolsCandidateCount'] = meekOnly ? 16 : 8;
    config['EstablishTunnelTimeoutSeconds'] = meekOnly ? 90 : 35;
    config['ConnectionWorkerPoolSize'] = meekOnly ? 8 : 6;
    config['DNSResolverPreferAlternateServerProbability'] = 0;
    config.remove('DNSResolverPreferredAlternateServers');
    if (meekOnly) {
      config['MeekTransformedHostName'] = 'cdnjs.cloudflare.com';
      config['MeekSNIServerName'] = 'cdnjs.cloudflare.com';
    }
  } else {
    config['LimitTunnelProtocols'] = chainable;
  }
  final preference = config['InitialLimitTunnelProtocols'];
  if (preference is List) {
    final filtered = [
      for (final p in preference) if (chainable.contains(p)) p,
    ];
    if (filtered.isEmpty) {
      config.remove('InitialLimitTunnelProtocols');
      config.remove('InitialLimitTunnelProtocolsCandidateCount');
    } else {
      config['InitialLimitTunnelProtocols'] = filtered;
    }
  }
  return json.encode(config);
}

const powRegionBundled = {
  'AT': 'Austria', 'AU': 'Australia', 'BE': 'Belgium', 'CA': 'Canada',
  'CH': 'Switzerland', 'CZ': 'Czechia', 'DE': 'Germany', 'DK': 'Denmark',
  'ES': 'Spain', 'FI': 'Finland', 'FR': 'France', 'GB': 'United Kingdom',
  'ID': 'Indonesia', 'IE': 'Ireland', 'IN': 'India', 'IT': 'Italy',
  'JP': 'Japan', 'NL': 'Netherlands', 'NO': 'Norway', 'PL': 'Poland',
  'RO': 'Romania', 'RS': 'Serbia', 'SE': 'Sweden', 'SG': 'Singapore',
  'US': 'United States',
};

const powRegionExtra = {
  'AE': 'United Arab Emirates', 'AR': 'Argentina', 'BG': 'Bulgaria',
  'BR': 'Brazil', 'CL': 'Chile', 'EE': 'Estonia', 'GR': 'Greece',
  'HK': 'Hong Kong', 'HU': 'Hungary', 'IL': 'Israel', 'IS': 'Iceland',
  'KR': 'South Korea', 'LT': 'Lithuania', 'LV': 'Latvia', 'MD': 'Moldova',
  'MX': 'Mexico', 'MY': 'Malaysia', 'NZ': 'New Zealand', 'PT': 'Portugal',
  'SK': 'Slovakia', 'TR': 'Türkiye', 'TW': 'Taiwan', 'UA': 'Ukraine',
};

final powRegionNames = {...powRegionBundled, ...powRegionExtra};

bool isRegionCode(String code) {
  final key = code.trim().toUpperCase();
  return RegExp(r'^[A-Z]{2}$').hasMatch(key);
}

String normalizeRegion(String? code) {
  final key = (code ?? '').trim().toUpperCase();
  if (isRegionCode(key)) return key.toLowerCase();
  return '';
}

String? egressRegion(String? code) {
  final normalized = normalizeRegion(code);
  return normalized.isEmpty ? null : normalized.toUpperCase();
}

String regionName(String code) {
  final key = normalizeRegion(code).toUpperCase();
  if (key.isEmpty) return '';
  return powRegionNames[key] ?? key;
}
