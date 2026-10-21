import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:fl_clash/features/updates/monitor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'returning to the window preserves the successful twelve hour interval',
    () {
      fakeAsync((async) {
        var calls = 0;
        final monitor = ReleaseMonitor(
          fetch: () async {
            calls++;
            return null;
          },
          readDismissed: () async => null,
          writeDismissed: (_) async {},
          now: () => DateTime(2026).add(async.elapsed),
        );
        monitor.start();
        async.flushMicrotasks();
        monitor.setVisible(false);
        async.elapse(const Duration(hours: 1));
        monitor.setVisible(true);
        async.flushMicrotasks();
        expect(calls, 1);
        async.elapse(const Duration(hours: 11));
        expect(calls, 2);
        monitor.dispose();
      });
    },
  );
  test(
    'concurrent checks share work and dismissal is version specific',
    () async {
      final pending = Completer<Map<String, dynamic>?>();
      var calls = 0;
      String? dismissed;
      final monitor = ReleaseMonitor(
        fetch: () {
          calls++;
          return pending.future;
        },
        readDismissed: () async => dismissed,
        writeDismissed: (value) async {
          dismissed = value;
        },
      );
      addTearDown(monitor.dispose);
      final first = monitor.check();
      final second = monitor.check();
      expect(calls, 1);
      pending.complete({'tag_name': 'v1.2.3'});
      await Future.wait([first, second]);
      expect(monitor.release?['tag_name'], 'v1.2.3');
      await monitor.dismiss();
      expect(dismissed, 'v1.2.3');
      expect(monitor.release, isNull);
      await monitor.check();
      expect(monitor.release, isNull);
    },
  );

  test(
    'failed checks retry, pause while hidden, and dispose cancels timers',
    () {
      fakeAsync((async) {
        var calls = 0;
        final monitor = ReleaseMonitor(
          fetch: () async {
            calls++;
            throw StateError('offline');
          },
          readDismissed: () async => null,
          writeDismissed: (_) async {},
          now: () => DateTime(2026).add(async.elapsed),
        );
        monitor.start();
        async.flushMicrotasks();
        expect(calls, 1);
        async.elapse(const Duration(seconds: 15));
        expect(calls, 2);
        monitor.setVisible(false);
        async.elapse(const Duration(minutes: 10));
        expect(calls, 2);
        monitor.setVisible(true);
        async.flushMicrotasks();
        expect(calls, 3);
        monitor.dispose();
        async.elapse(const Duration(days: 1));
        expect(calls, 3);
        expect(async.nonPeriodicTimerCount, 0);
        expect(async.periodicTimerCount, 0);
      });
    },
  );

  test(
    'invalid releases retry and disabled automatic checks stay quiet',
    () async {
      final monitor = ReleaseMonitor(
        fetch: () async => {'tag_name': 'v1.2.3-beta', 'prerelease': true},
        readDismissed: () async => null,
        writeDismissed: (_) async {},
      );
      addTearDown(monitor.dispose);
      await expectLater(monitor.check(), throwsFormatException);
      expect(monitor.release, isNull);
      monitor.setEnabled(false);
      expect(await monitor.check(), isNull);
      await expectLater(monitor.check(manual: true), throwsFormatException);
    },
  );

  test(
    'completion after disposal does not notify or start another timer',
    () async {
      final pending = Completer<Map<String, dynamic>?>();
      final monitor = ReleaseMonitor(
        fetch: () => pending.future,
        readDismissed: () async => null,
        writeDismissed: (_) async {},
      );
      final check = monitor.check();
      monitor.dispose();
      pending.complete({'tag_name': 'v2.0.0'});
      await check;
      expect(monitor.release, isNull);
    },
  );
}
