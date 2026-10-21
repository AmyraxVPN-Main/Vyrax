import 'string.dart';

String? normalizeProfileLink(String input) {
  var text = input.trim();
  for (var depth = 0; depth < 4; depth++) {
    if (text.isUrl || text.isShareLink) return text;
    final separator = text.indexOf('://');
    if (separator <= 0) return null;
    final scheme = text.substring(0, separator).toLowerCase();
    if (!const {
      'clash',
      'clashmeta',
      'flclash',
      'vyrax',
      'v2rayng',
      'v2rayn',
      'hiddify',
      'sing-box',
      'singbox',
      'happ',
    }.contains(scheme)) {
      return null;
    }
    try {
      if (scheme == 'hiddify' || scheme == 'happ') {
        var target = text.substring(separator + 3);
        if (target.startsWith('import/')) target = target.substring(7);
        if (target.startsWith('add/')) target = target.substring(4);
        final encoded =
            target.startsWith('http%') || target.startsWith('https%');
        if (target.startsWith('http://') ||
            target.startsWith('https://') ||
            encoded) {
          text = encoded ? Uri.decodeComponent(target) : target;
          continue;
        }
      }
      final uri = Uri.tryParse(text);
      if (uri == null) return null;
      if (const {
        'install-config',
        'install-sub',
        'import-remote-profile',
        'add-profile',
      }.contains(uri.host)) {
        text = uri.queryParameters['url']?.trim() ?? '';
      } else {
        return null;
      }
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }
  return null;
}
