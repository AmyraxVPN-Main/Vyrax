import 'dart:async';
import 'dart:io';

import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'accounts.dart';
import 'api.dart';
import 'runtime_config.dart';
import 'windows_proxy.dart';

class _SecureMozillaVault implements MozillaVault {
  static const _storage = FlutterSecureStorage();
  static const _key = 'mozilla-vpn-accounts-v1';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
}

final mozillaRuntimeProvider = Provider<MozillaRuntime>((ref) {
  final runtime = MozillaRuntime(ref);
  ref.onDispose(runtime.dispose);
  return runtime;
});

final mozillaAccountsProvider = Provider<MozillaAccounts>(
  (ref) => ref.watch(mozillaRuntimeProvider).accounts,
);

class MozillaRuntime {
  MozillaRuntime(this.ref) {
    accounts = MozillaAccounts(
      vault: _SecureMozillaVault(),
      api: MozillaApi(request: _request),
      beforeAccountChange: _stop,
    );
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(globalState.safeRun(_renew)),
    );
  }
  final Ref ref;
  late final MozillaAccounts accounts;
  late final Timer _timer;
  int? _profileId;
  bool _renewing = false;
  bool _disposed = false;
  String _appliedPass = '';

  Future<MozillaResponse> _request(
    String endpoint, {
    String body = '',
    String authorization = '',
  }) async {
    final address = MozillaApi.endpoints[endpoint];
    if (address == null) {
      throw const MozillaException(MozillaError.service);
    }
    String? proxy;
    if (Platform.isWindows &&
        !ref.read(safeModeProvider) &&
        (!ref.read(isStartProvider) || ref.read(suspendProvider))) {
      try {
        proxy = await windowsSystemProxy(
          Uri.parse(address),
        ).timeout(const Duration(seconds: 10));
      } catch (_) {
        throw const MozillaException(MozillaError.network);
      }
      if (_disposed) throw const MozillaException(MozillaError.network);
    }
    return MozillaApi.send(
      endpoint,
      body: body,
      authorization: authorization,
      proxy: proxy,
    );
  }

  bool get _selected =>
      _profileId != null && ref.read(currentProfileIdProvider) == _profileId;

  Future<void> _stop() async {
    if (_disposed) return;
    if (_selected && ref.read(isStartProvider)) {
      await ref.read(setupActionProvider.notifier).setRunning(false);
    }
    // Mozilla's generated profile is tied to the currently activated server
    // list/account. Do not leave a stale profile visible after the user
    // removes or switches that account.
    final profiles = ref.read(profilesProvider);
    if (profiles.any((profile) => profile.id == kMozillaSystemProfileId)) {
      await ref.read(profilesProvider.notifier).del(kMozillaSystemProfileId);
      await ref
          .read(profilesActionProvider.notifier)
          .clearEffect(kMozillaSystemProfileId);
      if (ref.read(currentProfileIdProvider) == kMozillaSystemProfileId) {
        final remaining = ref.read(profilesProvider);
        ref.read(currentProfileIdProvider.notifier).value = remaining.isNotEmpty
            ? remaining.first.id
            : null;
        if (remaining.isEmpty) {
          await ref.read(setupActionProvider.notifier).setRunning(false);
        }
      }
    }
    _profileId = null;
  }

  Future<void> _renew() async {
    if (_disposed ||
        _renewing ||
        !_selected ||
        !ref.read(isStartProvider) ||
        (!accounts.passNeedsRenewal && accounts.cachedPass == _appliedPass)) {
      return;
    }
    _renewing = true;
    final profileId = _profileId;
    try {
      await accounts.proxyPass();
      if (!_disposed &&
          _selected &&
          _profileId == profileId &&
          ref.read(isStartProvider)) {
        final applied = await ref
            .read(setupActionProvider.notifier)
            .applyProfile(force: true, silence: true);
        if (!applied) await _stop();
      }
    } catch (_) {
      if (!_disposed && _profileId == profileId) await _stop();
    } finally {
      _renewing = false;
    }
  }

  Future<Map<String, dynamic>> resolve(
    Map<String, dynamic> raw,
    int profileId,
  ) async {
    if (!hasMozillaProxies(raw)) {
      _profileId = null;
      return raw;
    }
    _profileId = profileId;
    final pass = await accounts.proxyPass();
    _appliedPass = pass;
    return resolveMozillaProxies(raw, pass);
  }

  void dispose() {
    _disposed = true;
    _timer.cancel();
    accounts.dispose();
  }
}
