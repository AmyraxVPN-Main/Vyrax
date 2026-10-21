import 'package:fl_clash/common/clipboard_profiles.dart';
import 'package:fl_clash/common/link.dart';
import 'package:fl_clash/common/profile_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const url = 'https://example.com/sub?token=a%2Fb&mode=full#Name';
  final encoded = Uri.encodeComponent(url);
  final links = [
    url,
    'hiddify://import/$url',
    'hiddify://$url',
    'hiddify://import/$encoded',
    'happ://add/$url',
    'v2rayng://install-config?url=$encoded',
    'v2rayn://install-sub?url=$encoded',
    'sing-box://import-remote-profile?url=$encoded',
    'clash://install-config?url=$encoded',
  ];
  test(
    'all entry points unwrap subscription links without changing tokens',
    () {
      for (final link in links) {
        expect(normalizeProfileLink(' $link '), url);
        expect(parseClipboardProfileLinks(link), [url]);
        expect(profileUrlFromQrCodes([link]), url);
      }
      expect(parseClipboardProfileLinks(links.join('\n')), [url]);
    },
  );
  test('rejects unrelated actions and non-network targets', () {
    for (final link in [
      'hiddify://import/file:///private',
      'clash://open-profile?url=$encoded',
      'other://install-config?url=$encoded',
      'sing-box://import-remote-profile?url=invalid',
      'hiddify://import/%XX',
    ]) {
      expect(normalizeProfileLink(link), isNull);
    }
  });
}
