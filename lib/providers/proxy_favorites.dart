import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final proxyFavoritesProvider =
    AsyncNotifierProvider<ProxyFavorites, Map<String, Set<String>>>(
      ProxyFavorites.new,
    );
final favoriteProxiesOnlyProvider = NotifierProvider<FavoriteProxiesOnly, bool>(
  FavoriteProxiesOnly.new,
);

class FavoriteProxiesOnly extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

class ProxyFavorites extends AsyncNotifier<Map<String, Set<String>>> {
  static const _key = 'proxy-favorites-v1';
  Future<void> _queue = Future.value();

  @override
  Future<Map<String, Set<String>>> build() async {
    final store = await preferences.sharedPreferencesCompleter.future;
    final raw = store?.getString(_key);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final entry in decoded.entries)
        entry.key: Set<String>.from(entry.value as List),
    };
  }

  Future<void> toggle(int profileId, String name) {
    final result = _queue.then((_) async {
      final previous = await future;
      final next = {
        for (final entry in previous.entries) entry.key: {...entry.value},
      };
      final favorites = next.putIfAbsent('$profileId', () => <String>{});
      if (!favorites.add(name)) favorites.remove(name);
      if (favorites.isEmpty) next.remove('$profileId');
      final store = await preferences.sharedPreferencesCompleter.future;
      if (store == null ||
          !await store.setString(
            _key,
            jsonEncode({
              for (final entry in next.entries) entry.key: entry.value.toList(),
            }),
          )) {
        throw StateError('Could not save favorites');
      }
      if (ref.mounted) state = AsyncData(next);
    });
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
