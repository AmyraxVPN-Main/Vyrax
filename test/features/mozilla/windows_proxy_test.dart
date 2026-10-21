import 'package:fl_clash/features/mozilla/windows_proxy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final url = Uri.parse('https://api.accounts.firefox.com/v1/account/login');

  test('respects the system proxy for HTTPS without a direct fallback', () {
    expect(
      windowsProxyDirective(url, '127.0.0.1:10809', ''),
      'PROXY 127.0.0.1:10809',
    );
    expect(
      windowsProxyDirective(url, 'http=localhost:80;https=localhost:8080', ''),
      'PROXY localhost:8080',
    );
    expect(windowsProxyDirective(url, '[::1]:7890', ''), 'PROXY [::1]:7890');
    expect(windowsProxyDirective(url, 'localhost', ''), 'PROXY localhost:80');
  });

  test('respects system direct and bypass decisions', () {
    expect(windowsProxyDirective(url, '', ''), 'DIRECT');
    expect(windowsProxyDirective(url, 'http=localhost:8080', ''), 'DIRECT');
    expect(
      windowsProxyDirective(url, 'localhost:8080', '*.FIREFOX.com'),
      'DIRECT',
    );
    expect(
      windowsProxyDirective(url, 'localhost:8080', '<local>'),
      'PROXY localhost:8080',
    );
    expect(
      windowsProxyDirective(
        Uri.parse('https://intranet'),
        'localhost:8080',
        '<local>',
      ),
      'DIRECT',
    );
  });

  test('malformed proxy configuration does not fall back to direct', () {
    for (final proxy in [
      'host:0',
      'host:65536',
      'host:8080/path',
      'host:8080?token=secret',
      'user:secret@host:8080',
      'socks://host:1080',
      'host:8080\r\nDIRECT',
    ]) {
      expect(
        () => windowsProxyDirective(url, proxy, ''),
        throwsA(isA<FormatException>()),
      );
    }
  });
}
