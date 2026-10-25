import 'dart:async';

import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/features/pow/engine.dart';
import 'package:fl_clash/features/pow/models.dart' as pow_models;
import 'package:fl_clash/features/pow/status.dart';
import 'package:flutter/services.dart';

/// Android side of Vyrax Free: drives the UAC Aether (WARP/MASQUE) engine that
/// runs in the `:uacpow` process and publishes a loopback SOCKS proxy.
class PowAndroidEngine {
  PowAndroidEngine() {
    _events = _eventChannel.receiveBroadcastStream().listen(
      _onEvent,
      onError: (Object error) {
        _fail('PoW engine channel error: $error');
      },
    );
  }

  static const _methodChannel = MethodChannel('$packageName/pow');
  static const _eventChannel = EventChannel('$packageName/pow/events');

  final PowStatusStore status = PowStatusStore();

  StreamSubscription<Object?>? _events;
  Completer<void>? _connected;
  int _port = 0;
  bool _isConnected = false;
  bool _busy = false;
  bool _disposed = false;

  bool get connected => _isConnected;
  int get exitPort => _port;
  bool get busy => _busy;

  Future<void> connect(pow_models.PowSettings settings) async {
    if (_busy || _disposed) return;
    _busy = true;
    _isConnected = false;
    _port = 0;
    final connected = Completer<void>();
    _connected = connected;
    _emit(PowPhase.outer, 10, 'Aether: preparing WARP', outerLabel: 'WARP');

    // The outer transport is Aether's MASQUE path for the automatic recipe and
    // WireGuard when the user explicitly picked it.
    final protocol = settings.outerTransport == 'wireguard'
        ? 'wireguard'
        : 'masque';
    try {
      await _methodChannel.invokeMethod<void>('start', {
        'protocol': protocol,
        'scanMode': settings.scanMode,
        'region': settings.exitCountryCode,
      });
      await connected.future.timeout(const Duration(minutes: 3));
    } on TimeoutException {
      await disconnect();
      throw const PowEngineException('pow-timeout');
    } catch (error) {
      await disconnect();
      if (error is PowEngineException) rethrow;
      throw PowEngineException('$error');
    } finally {
      _busy = false;
      _connected = null;
    }
  }

  Future<void> disconnect() async {
    _isConnected = false;
    _port = 0;
    _busy = false;
    final pending = _connected;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const PowEngineException('stopped'));
    }
    _connected = null;
    try {
      await _methodChannel.invokeMethod<void>('stop');
    } catch (_) {
      // The service may already be gone.
    }
    if (!_disposed) {
      status.update(PowPhase.idle, 0, '');
    }
  }

  void dispose() {
    _disposed = true;
    _events?.cancel();
    _events = null;
    unawaited(_methodChannel.invokeMethod<void>('stop').catchError((_) {}));
  }

  void _onEvent(Object? raw) {
    if (_disposed || raw is! Map) return;
    final map = raw.cast<Object?, Object?>();
    final event = map['event'] as String? ?? 'state';
    final message = map['message'] as String? ?? '';
    if (event == 'failed') {
      _fail(message.isEmpty ? 'Aether engine failed' : message);
      return;
    }
    if (event == 'stopped') {
      _isConnected = false;
      _port = 0;
      _busy = false;
      status.update(PowPhase.idle, 0, '');
      final pending = _connected;
      if (pending != null && !pending.isCompleted) {
        pending.completeError(const PowEngineException('stopped'));
      }
      return;
    }
    final phase = map['phase'] as String? ?? '';
    switch (phase) {
      case 'preparing':
        _emit(PowPhase.outer, 25, 'Aether: WARP handshake', outerLabel: 'WARP');
      case 'starting':
        _emit(PowPhase.inner, 60, 'Aether: starting the local SOCKS', outerLabel: 'WARP');
      case 'connected':
        final port = (map['port'] as num?)?.toInt() ?? 0;
        _port = port;
        _isConnected = port > 0;
        _busy = false;
        _emit(
          PowPhase.connected,
          100,
          port > 0 ? '127.0.0.1:$port' : '',
          outerLabel: 'WARP',
        );
        final pending = _connected;
        if (pending != null && !pending.isCompleted) pending.complete();
    }
  }

  void _fail(String message) {
    _busy = false;
    _isConnected = false;
    _port = 0;
    status.update(PowPhase.failed, 0, message);
    final pending = _connected;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(PowEngineException(message));
    }
  }

  void _emit(
    PowPhase phase,
    int progress,
    String detail, {
    String? outerLabel,
  }) {
    if (_disposed) return;
    status.update(phase, progress, detail, outerLabel: outerLabel);
  }
}
