import 'dart:async';

import 'package:flutter/foundation.dart';

class ReleaseMonitor extends ChangeNotifier {
  ReleaseMonitor({
    required this.fetch,
    required this.readDismissed,
    required this.writeDismissed,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final Future<Map<String, dynamic>?> Function() fetch;
  final Future<String?> Function() readDismissed;
  final Future<void> Function(String) writeDismissed;
  final DateTime Function() now;
  Map<String, dynamic>? release;
  Future<Map<String, dynamic>?>? _pending;
  Timer? _timer;
  DateTime? _due;
  DateTime? _lastAttempt;
  int _failures = 0;
  bool _enabled = true;
  bool _visible = true;
  bool _disposed = false;
  static const _retries = [
    Duration(seconds: 15),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];

  void setEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    if (!value) {
      _timer?.cancel();
      release = null;
      notifyListeners();
    } else {
      start();
    }
  }

  void setVisible(bool value) {
    if (_visible == value) return;
    _visible = value;
    if (!value) {
      _timer?.cancel();
      return;
    }
    if (_due == null ||
        !_due!.isAfter(now()) ||
        _lastAttempt == null ||
        (_failures > 0 &&
            now().difference(_lastAttempt!) >= const Duration(minutes: 1))) {
      start();
    } else {
      _schedule(_due!.difference(now()));
    }
  }

  void start() {
    if (!_disposed && _enabled && _visible) {
      unawaited(check().catchError((Object _) => null));
    }
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _due = now().add(delay);
    if (!_disposed && _enabled && _visible) _timer = Timer(delay, start);
  }

  Future<Map<String, dynamic>?> check({bool manual = false}) {
    if (_disposed || (!manual && !_enabled)) return Future.value(null);
    return _pending ??= _perform().whenComplete(() {
      _pending = null;
    });
  }

  Future<Map<String, dynamic>?> _perform() async {
    _lastAttempt = now();
    try {
      final data = await fetch();
      final tag = data?['tag_name'];
      final valid =
          data == null ||
          (tag is String &&
              RegExp(r'^v?\d+\.\d+\.\d+$').hasMatch(tag) &&
              data['draft'] != true &&
              data['prerelease'] != true);
      if (!valid) throw const FormatException('Invalid stable release');
      final dismissed = await readDismissed();
      if (!_disposed) {
        release = _enabled && tag != dismissed ? data : null;
        _failures = 0;
        _schedule(const Duration(hours: 12));
        notifyListeners();
      }
      return data;
    } catch (_) {
      if (!_disposed) {
        _schedule(_retries[_failures.clamp(0, _retries.length - 1)]);
        _failures++;
      }
      rethrow;
    }
  }

  Future<void> dismiss() async {
    final current = release;
    if (current == null) return;
    final tag = current['tag_name'] as String;
    await writeDismissed(tag);
    if (!_disposed && release?['tag_name'] == tag) {
      release = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
