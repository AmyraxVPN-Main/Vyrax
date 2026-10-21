import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/providers/proxy_favorites.dart';
import 'package:fl_clash/providers/saved_exit_ips.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await preferences.sharedPreferencesCompleter.future;
    preferences.sharedPreferencesCompleter = Completer<SharedPreferences?>()
      ..complete(await SharedPreferences.getInstance());
  });

  test(
    'favorites filter combines with search and the selected profile',
    () async {
      final container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
          visibleGroupsStateProvider.overrideWith(
            (_) => const GroupsState(
              value: [
                Group(
                  name: 'group',
                  type: GroupType.Selector,
                  hidden: false,
                  all: [
                    Proxy(name: 'Paris', type: 'http'),
                    Proxy(name: 'Tokyo', type: 'http'),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final favorites = container.read(proxyFavoritesProvider.notifier);
      await favorites.toggle(1, 'Paris');
      await favorites.toggle(2, 'Tokyo');
      container.read(favoriteProxiesOnlyProvider.notifier).toggle();
      expect(
        container
            .read(filterGroupsStateProvider(''))
            .value
            .single
            .all
            .map((p) => p.name),
        ['Paris'],
      );
      expect(container.read(filterGroupsStateProvider('Tokyo')).value, isEmpty);
      container.read(currentProfileIdProvider.notifier).value = 2;
      expect(
        container
            .read(filterGroupsStateProvider(''))
            .value
            .single
            .all
            .map((p) => p.name),
        ['Tokyo'],
      );
      container.read(favoriteProxiesOnlyProvider.notifier).toggle();
      expect(
        container
            .read(filterGroupsStateProvider('Paris'))
            .value
            .single
            .all
            .map((p) => p.name),
        ['Paris'],
      );
    },
  );

  test(
    'concurrent favorite changes persist independently by profile',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final favorites = container.read(proxyFavoritesProvider.notifier);
      await Future.wait([
        favorites.toggle(1, 'one'),
        favorites.toggle(1, 'two'),
        favorites.toggle(2, 'one'),
      ]);
      expect(await container.read(proxyFavoritesProvider.future), {
        '1': {'one', 'two'},
        '2': {'one'},
      });
      final restored = ProviderContainer();
      addTearDown(restored.dispose);
      expect(await restored.read(proxyFavoritesProvider.future), {
        '1': {'one', 'two'},
        '2': {'one'},
      });
      await favorites.toggle(1, 'one');
      expect((await container.read(proxyFavoritesProvider.future))['1'], {
        'two',
      });
    },
  );

  test('saved IP changes serialize and survive a fresh container', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ips = container.read(savedExitIpsProvider.notifier);
    await Future.wait([
      ips.toggle('192.0.2.1', 'US'),
      ips.toggle('2001:db8::1', 'DE'),
    ]);
    await ips.toggle('192.0.2.1', 'US');
    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    expect(await restored.read(savedExitIpsProvider.future), {
      '2001:db8::1': 'DE',
    });
  });

  test('unavailable storage rejects a change without mutating state', () async {
    preferences.sharedPreferencesCompleter = Completer<SharedPreferences?>()
      ..complete(null);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await expectLater(
      container.read(proxyFavoritesProvider.notifier).toggle(1, 'one'),
      throwsStateError,
    );
    expect(await container.read(proxyFavoritesProvider.future), isEmpty);
    await expectLater(
      container.read(savedExitIpsProvider.notifier).toggle('192.0.2.1', 'US'),
      throwsStateError,
    );
    expect(await container.read(savedExitIpsProvider.future), isEmpty);
  });
}
