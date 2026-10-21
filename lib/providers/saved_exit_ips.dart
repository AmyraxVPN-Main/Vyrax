import 'dart:convert';
import 'package:fl_clash/common/common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final savedExitIpsProvider =
    AsyncNotifierProvider<SavedExitIps, Map<String, String>>(SavedExitIps.new);

class SavedExitIps extends AsyncNotifier<Map<String, String>> {
  static const _key = 'saved-exit-ips-v1';
  Future<void> _queue = Future.value();
  @override
  Future<Map<String, String>> build() async {
    final store = await preferences.sharedPreferencesCompleter.future;
    final value = store?.getString(_key);
    return value == null
        ? {}
        : Map<String, String>.from(jsonDecode(value) as Map);
  }

  Future<void> toggle(String ip, String countryCode) {
    final result = _queue.then((_) async {
      final next = {...await future};
      if (next.containsKey(ip)) {
        next.remove(ip);
      } else {
        next[ip] = countryCode;
      }
      final store = await preferences.sharedPreferencesCompleter.future;
      if (store == null || !await store.setString(_key, jsonEncode(next))) {
        throw StateError('Could not save IP');
      }
      if (ref.mounted) state = AsyncData(next);
    });
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
