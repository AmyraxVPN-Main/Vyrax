import 'package:fl_clash/common/country_flag.dart';
import 'package:fl_clash/common/string.dart';
import 'package:flutter/material.dart';
import 'package:material_ui/material_ui.dart';

/// Auto-detects a country for config names that carry no flag emoji.
///
/// Provider node names usually embed a location as an ISO code token
/// ("DE-01"), an English country name ("Germany-01") or a well-known city
/// ("Frankfurt-01"). Returns the ISO-3166 alpha-2 code in lower case, or
/// null when the name already contains a flag emoji or nothing matches.
const configFlagNames = <String, String>{
  // countries
  'united states': 'US',
  'united kingdom': 'GB',
  'united arab': 'AE',
  'new york': 'US',
  'los angeles': 'US',
  'hong kong': 'HK',
  'south korea': 'KR',
  'saudi': 'SA',
  // single tokens
  'germany': 'DE',
  'german': 'DE',
  'deutschland': 'DE',
  'netherlands': 'NL',
  'holland': 'NL',
  'dutch': 'NL',
  'france': 'FR',
  'french': 'FR',
  'britain': 'GB',
  'england': 'GB',
  'london': 'GB',
  'america': 'US',
  'states': 'US',
  'dallas': 'US',
  'washington': 'US',
  'seattle': 'US',
  'chicago': 'US',
  'miami': 'US',
  'ashburn': 'US',
  'phoenix': 'US',
  'atlanta': 'US',
  'turkey': 'TR',
  'turkiye': 'TR',
  'istanbul': 'TR',
  'russia': 'RU',
  'moscow': 'RU',
  'spain': 'ES',
  'madrid': 'ES',
  'italy': 'IT',
  'rome': 'IT',
  'milan': 'IT',
  'poland': 'PL',
  'warsaw': 'PL',
  'sweden': 'SE',
  'stockholm': 'SE',
  'austria': 'AT',
  'vienna': 'AT',
  'switzerland': 'CH',
  'zurich': 'CH',
  'canada': 'CA',
  'toronto': 'CA',
  'montreal': 'CA',
  'japan': 'JP',
  'tokyo': 'JP',
  'osaka': 'JP',
  'singapore': 'SG',
  'korea': 'KR',
  'seoul': 'KR',
  'india': 'IN',
  'mumbai': 'IN',
  'indonesia': 'ID',
  'jakarta': 'ID',
  'iran': 'IR',
  'tehran': 'IR',
  'russia federation': 'RU',
  'ukraine': 'UA',
  'kyiv': 'UA',
  'kiev': 'UA',
  'portugal': 'PT',
  'lisbon': 'PT',
  'romania': 'RO',
  'bucharest': 'RO',
  'serbia': 'RS',
  'belgrade': 'RS',
  'czech': 'CZ',
  'prague': 'CZ',
  'denmark': 'DK',
  'copenhagen': 'DK',
  'norway': 'NO',
  'oslo': 'NO',
  'finland': 'FI',
  'helsinki': 'FI',
  'ireland': 'IE',
  'dublin': 'IE',
  'belgium': 'BE',
  'brussels': 'BE',
  'greece': 'GR',
  'athens': 'GR',
  'hungary': 'HU',
  'budapest': 'HU',
  'emirates': 'AE',
  'dubai': 'AE',
  'australia': 'AU',
  'sydney': 'AU',
  'brazil': 'BR',
  'mexico': 'MX',
  'malaysia': 'MY',
  'israel': 'IL',
  'vietnam': 'VN',
  'thailand': 'TH',
  'philippines': 'PH',
  'argentina': 'AR',
  'chile': 'CL',
  'egypt': 'EG',
  'china': 'CN',
  'taiwan': 'TW',
  'berlin': 'DE',
  'munich': 'DE',
  'frankfurt': 'DE',
  'amsterdam': 'NL',
  'paris': 'FR',
  'frankfurt am': 'DE',
};

/// Standalone upper-case tokens that are accepted as country codes.
/// Lower-case or mixed-case two-letter words are too ambiguous.
const configFlagCodes = <String, String>{
  'DE': 'de',
  'NL': 'nl',
  'FR': 'fr',
  'GB': 'gb',
  'UK': 'gb',
  'US': 'us',
  'USA': 'us',
  'TR': 'tr',
  'RU': 'ru',
  'AE': 'ae',
  'IR': 'ir',
  'CA': 'ca',
  'JP': 'jp',
  'SG': 'sg',
  'HK': 'hk',
  'KR': 'kr',
  'IT': 'it',
  'ES': 'es',
  'PL': 'pl',
  'SE': 'se',
  'AT': 'at',
  'CH': 'ch',
  'AU': 'au',
  'BR': 'br',
  'MX': 'mx',
  'MY': 'my',
  'IL': 'il',
  'ID': 'id',
  'IN': 'in',
  'UA': 'ua',
  'PT': 'pt',
  'RO': 'ro',
  'RS': 'rs',
  'CZ': 'cz',
  'DK': 'dk',
  'NO': 'no',
  'FI': 'fi',
  'IE': 'ie',
  'BE': 'be',
  'GR': 'gr',
  'HU': 'hu',
  'LT': 'lt',
  'LV': 'lv',
  'EE': 'ee',
  'SK': 'sk',
  'BG': 'bg',
  'VN': 'vn',
  'TH': 'th',
  'PH': 'ph',
  'AR': 'ar',
  'CL': 'cl',
  'EG': 'eg',
  'CN': 'cn',
  'TW': 'tw',
  'SA': 'sa',
};

/// Regional-indicator flag emoji (surrogate pair D83C DDE6..DDFF).
final _flagEmojiRegex = RegExp('[\uD83C][\uDDE6-\uDDFF]');

final _tokenRegex = RegExp(r'[A-Za-z]+');

/// ISO code behind [name], or null when the name already carries a flag.
String? configFlagCode(String name) {
  if (_flagEmojiRegex.hasMatch(name)) {
    return null;
  }
  final lower = name.toLowerCase();
  // Longest multi-word phrases first so "united states" beats "states".
  final keys = configFlagNames.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final key in keys) {
    if (lower.contains(key)) {
      return configFlagNames[key]?.toLowerCase();
    }
  }
  for (final match in _tokenRegex.allMatches(name)) {
    final code = configFlagCodes[match.group(0)];
    if (code != null) {
      return code;
    }
  }
  return null;
}

/// Flag emoji for a config name that has none, else the name untouched.
String flagIfMissing(String name) {
  final code = configFlagCode(name);
  if (code == null) {
    return name;
  }
  return '${code.toUpperCase().countryFlagEmoji} $name';
}

/// Flag badge derived purely from the config name: collapses to nothing
/// when the name already carries a flag or no location can be detected.
class ConfigFlagBadge extends StatelessWidget {
  final String name;
  final double fontSize;

  const ConfigFlagBadge(this.name, {super.key, this.fontSize = 14});

  @override
  Widget build(BuildContext context) {
    final code = configFlagCode(name);
    if (code == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: CountryFlagEmoji(
        code.toUpperCase(),
        style: TextStyle(fontSize: fontSize, height: 1.2),
      ),
    );
  }
}
