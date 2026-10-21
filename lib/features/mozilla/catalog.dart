import 'api.dart';

final _edge = RegExp(
  r'^[a-z0-9]+(?:[.-][a-z0-9]+)*\.fastly-masque\.net$',
  caseSensitive: false,
);

bool isMozillaEdge(Object? host) =>
    host is String && host.length <= 253 && _edge.hasMatch(host);

List<Map<String, dynamic>> parseMozillaServers(
  Map<String, dynamic> raw, {
  Map<String, String>? countryCodes,
}) {
  final records = raw['data'];
  if (records is! List) throw const MozillaException(MozillaError.service);
  final result = <String, Map<String, dynamic>>{};
  for (final record in records.whereType<Map>()) {
    final country = record['country'] is Map
        ? record['country'] as Map
        : record;
    final Object? rawCode = country['code'];
    if (rawCode is! String ||
        rawCode.trim().isEmpty ||
        country['name'] == 'CatchAll Anycast') {
      continue;
    }
    final code = rawCode;
    final cities = country['cities'];
    if (cities is! List) continue;
    for (final city in cities.whereType<Map>()) {
      final servers = city['servers'];
      if (servers is! List) continue;
      for (final server in servers.whereType<Map>()) {
        if (server['quarantined'] == true) continue;
        final protocols = server['protocols'];
        Map? protocol;
        if (protocols is List) {
          for (final candidate in protocols.whereType<Map>()) {
            if (candidate['name'] == 'connect') {
              protocol = candidate;
              break;
            }
          }
          if (protocols.isNotEmpty && protocol == null) continue;
        }
        final host = (protocol?['host'] ?? server['hostname'])
            ?.toString()
            .toLowerCase();
        final port = protocol?['port'] ?? server['port'];
        final edgeHost = host ?? '';
        if (!isMozillaEdge(edgeHost) ||
            port is! int ||
            port < 1 ||
            port > 65535) {
          continue;
        }
        final countryName = (country['name'] ?? code).toString();
        final cityName = city['name'] != countryName
            ? city['name']
            : city['code'];
        final name = code == 'REC'
            ? 'Recommended'
            : [
                countryName,
                if (cityName != null && cityName != code) cityName,
              ].join(' · ');
        result['$host:$port'] = {
          'name': '$name · $host:$port',
          'type': 'http',
          'server': host,
          'port': port,
          'tls': true,
          'sni': host,
          'network': 'h2',
          'skip-cert-verify': false,
          'x-flclash-mozilla': true,
        };
        if (countryCodes != null) {
          countryCodes[edgeHost] = code;
        }
        if (result.length > 256) {
          throw const MozillaException(MozillaError.service);
        }
      }
    }
  }
  if (result.isEmpty) throw const MozillaException(MozillaError.noServers);
  return result.values.toList()
    ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
}

Map<String, dynamic> mozillaProfile(List<Map<String, dynamic>> proxies) {
  final names = [for (final proxy in proxies) proxy['name'] as String];
  return {
    'proxies': proxies,
    'proxy-groups': [
      {
        'name': 'PROXY',
        'type': 'select',
        'proxies': ['FASTEST', 'BALANCE', ...names],
      },
      {
        'name': 'FASTEST',
        'type': 'url-test',
        'proxies': names,
        'url': 'https://www.gstatic.com/generate_204',
        'interval': 300,
      },
      {
        'name': 'BALANCE',
        'type': 'load-balance',
        'strategy': 'consistent-hashing',
        'proxies': names,
        'url': 'https://www.gstatic.com/generate_204',
        'interval': 300,
      },
    ],
    'dns': {
      'enable': true,
      'enhanced-mode': 'fake-ip',
      'default-nameserver': ['1.1.1.1'],
      'proxy-server-nameserver': ['https://1.1.1.1/dns-query'],
      'nameserver': ['https://1.1.1.1/dns-query#PROXY'],
    },
    'rules': ['NETWORK,udp,REJECT', 'MATCH,PROXY'],
  };
}
