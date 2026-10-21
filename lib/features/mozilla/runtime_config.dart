import 'api.dart';
import 'catalog.dart';

bool hasMozillaProxies(Map raw) {
  final proxies = raw['proxies'];
  return proxies is List &&
      proxies.whereType<Map>().any((p) => p['x-flclash-mozilla'] == true);
}

Map<String, dynamic> resolveMozillaProxies(
  Map<String, dynamic> raw,
  String pass,
) {
  if (!hasMozillaProxies(raw)) return raw;
  final resolved = <Map<String, dynamic>>[];
  for (final proxy in raw['proxies'] as List) {
    if (proxy is! Map) throw const MozillaException(MozillaError.service);
    final definition = Map<String, dynamic>.from(proxy);
    if (definition['x-flclash-mozilla'] == true) {
      final port = definition['port'];
      if (!isMozillaEdge(definition['server']) ||
          port is! int ||
          port < 1 ||
          port > 65535) {
        throw const MozillaException(MozillaError.noServers);
      }
      definition.addAll({
        'type': 'http',
        'network': 'h2',
        'tls': true,
        'sni': definition['server'],
        'skip-cert-verify': false,
        'headers': {'Proxy-Authorization': 'Bearer $pass'},
      });
      definition.remove('username');
      definition.remove('password');
    }
    resolved.add(definition);
  }
  return {...raw, 'proxies': resolved};
}

void protectMozillaTraffic(Map raw) {
  if (!hasMozillaProxies(raw)) return;
  final dns = mozillaProfile(const [])['dns'] as Map<String, dynamic>;
  final listen = raw['dns'] is Map ? raw['dns']['listen'] : null;
  raw['dns'] = {...dns, 'listen': ?listen};
  final rules = List<String>.from(raw['rules'] ?? const []);
  raw['rules'] = [
    'NETWORK,udp,REJECT',
    ...rules.where((rule) => rule != 'NETWORK,udp,REJECT'),
  ];
}
