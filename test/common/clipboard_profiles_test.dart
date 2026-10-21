import 'package:fl_clash/common/clipboard_profiles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('imports a mixed batch once, keeping encoded query and labels', () {
    const vless =
        'vless://00000000-0000-4000-8000-000000000001@example.com:8080?security=none&type=xhttp&mode=packet-up&path=%2Ftest#Example node';
    const ss = 'ss://YWVzLTI1Ni1nY206dGVzdA@example.com:8080#SS';
    expect(parseClipboardProfileLinks('\r\n$vless\r\n$ss\n$vless\n'), [
      vless,
      ss,
    ]);
  });

  test('rejects empty, mixed invalid and oversized batches atomically', () {
    for (final text in [
      '',
      '   ',
      'https://example.com/sub\ninvalid',
      'x' * (2 * 1024 * 1024 + 1),
    ]) {
      expect(() => parseClipboardProfileLinks(text), throwsFormatException);
    }
  });
}
