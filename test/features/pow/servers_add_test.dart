import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/features/pow/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('pow-add');
  });
  tearDown(() {
    dir.deleteSync(recursive: true);
  });

  test('add after removing all servers recreates a slot', () {
    final store = PowStore(dir);
    expect(store.servers().length, 1);
    store.removeServer(store.servers().first.id);
    expect(store.servers(), isEmpty);
    expect(store.activeServerId(), '');
    store.addServer('de');
    expect(store.servers().length, 1);
    expect(store.activeServer()?.region, 'de');
    final reloaded = PowStore(dir);
    expect(reloaded.servers().length, 1);
    expect(reloaded.activeServer()?.region, 'de');
  });

  test('store keeps an explicit empty servers list empty', () {
    File('${dir.path}${Platform.pathSeparator}pow_settings.json')
        .writeAsStringSync(
      jsonEncode({'servers': [], 'active_server': '', 'settings_version': 2}),
    );
    final store = PowStore(dir);
    expect(store.servers(), isEmpty);
    store.addServer('nl');
    expect(store.servers().length, 1);
    expect(store.servers().first.id, 's1');
    expect(store.activeServer()?.region, 'nl');
  });
}
