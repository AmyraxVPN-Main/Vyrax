import 'dart:io';

import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/path.dart';
import 'package:fl_clash/common/profile_link.dart';
import 'package:fl_clash/common/protocol.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'Vyrax identity routes updates and install links to its own project',
    () {
      expect(appName, 'Vyrax');
      expect(repository, 'AmyraxVPN-Main/Vyrax');
      expect(appHelperService, 'VyraxHelperService');
      expect(protocolSchemes, contains('vyrax'));
      expect(
        normalizeProfileLink(
          'vyrax://install-config?url=https%3A%2F%2Fexample.com%2Fsub',
        ),
        'https://example.com/sub',
      );
    },
  );
  test(
    'an existing profile store is reused without copying or overwriting it',
    () async {
      final root = await Directory.systemTemp.createTemp('vyrax-data-test-');
      addTearDown(() => root.delete(recursive: true));
      final current = await Directory(p.join(root.path, 'Vyrax')).create();
      final legacy = await Directory(p.join(root.path, 'clash')).create();
      final oldDb = File(p.join(legacy.path, 'database.sqlite'));
      await oldDb.writeAsString('legacy-fixture');
      expect(
        (await compatibleDataDirectory(current, legacy)).path,
        legacy.path,
      );
      expect(await oldDb.readAsString(), 'legacy-fixture');
      await File(
        p.join(current.path, 'database.sqlite'),
      ).writeAsString('new-fixture');
      expect(
        (await compatibleDataDirectory(current, legacy)).path,
        current.path,
      );
      expect(await oldDb.readAsString(), 'legacy-fixture');
    },
  );
}
