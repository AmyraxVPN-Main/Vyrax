import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

final class _UserProxy extends Struct {
  @Int32()
  external int autoDetect;
  external Pointer<Utf16> configUrl;
  external Pointer<Utf16> proxy;
  external Pointer<Utf16> bypass;
}

final class _AutoProxyOptions extends Struct {
  @Uint32()
  external int flags;
  @Uint32()
  external int detectFlags;
  external Pointer<Utf16> configUrl;
  external Pointer<Void> reserved;
  @Uint32()
  external int reservedFlags;
  @Int32()
  external int autoLogon;
}

final class _ProxyInfo extends Struct {
  @Uint32()
  external int accessType;
  external Pointer<Utf16> proxy;
  external Pointer<Utf16> bypass;
}

String _string(Pointer<Utf16> value) =>
    value == nullptr ? '' : value.toDartString();

String windowsProxyDirective(Uri uri, String proxy, String bypass) {
  if (proxy.contains(RegExp(r'[\r\n\x00]'))) {
    throw const FormatException('Unsupported system proxy');
  }
  for (final pattern in bypass.split(';').map((s) => s.trim())) {
    if (pattern.isEmpty) continue;
    if (pattern.toLowerCase() == '<local>' && !uri.host.contains('.')) {
      return 'DIRECT';
    }
    final expression = RegExp.escape(pattern).replaceAll(r'\*', '.*');
    if (RegExp('^$expression\$', caseSensitive: false).hasMatch(uri.host)) {
      return 'DIRECT';
    }
  }
  String? selected;
  for (final entry in proxy.split(';').map((s) => s.trim())) {
    final parts = entry.split('=');
    if (parts.length > 1 &&
        (parts.length != 2 ||
            !{'http', 'https', 'ftp', 'socks'}.contains(parts.first))) {
      throw const FormatException('Unsupported system proxy');
    }
    if (parts.length == 1 && !entry.contains(RegExp(r'\s'))) {
      selected ??= entry;
    } else if (parts.length == 2 && parts.first == uri.scheme) {
      selected = parts.last;
      break;
    }
  }
  if (selected == null || selected.isEmpty) {
    if (proxy.trim().isEmpty || proxy.contains('=')) return 'DIRECT';
    throw const FormatException('Unsupported system proxy');
  }
  final address = Uri.tryParse(
    selected.contains('://') ? selected : 'http://$selected',
  );
  if (address == null ||
      address.scheme != 'http' ||
      address.host.isEmpty ||
      address.userInfo.isNotEmpty ||
      address.path.isNotEmpty ||
      address.hasQuery ||
      address.hasFragment ||
      address.port < 1 ||
      address.port > 65535) {
    throw const FormatException('Unsupported system proxy');
  }
  final host = address.host.contains(':') ? '[${address.host}]' : address.host;
  return 'PROXY $host:${address.port}';
}

Future<String> windowsSystemProxy(Uri uri) =>
    Isolate.run(() => _resolveWindowsProxy(uri));

String _resolveWindowsProxy(Uri uri) {
  final library = DynamicLibrary.open('winhttp.dll');
  final getConfig = library
      .lookupFunction<
        Int32 Function(Pointer<_UserProxy>),
        int Function(Pointer<_UserProxy>)
      >('WinHttpGetIEProxyConfigForCurrentUser');
  final open = library
      .lookupFunction<
        Pointer<Void> Function(
          Pointer<Utf16>,
          Uint32,
          Pointer<Utf16>,
          Pointer<Utf16>,
          Uint32,
        ),
        Pointer<Void> Function(
          Pointer<Utf16>,
          int,
          Pointer<Utf16>,
          Pointer<Utf16>,
          int,
        )
      >('WinHttpOpen');
  final resolve = library
      .lookupFunction<
        Int32 Function(
          Pointer<Void>,
          Pointer<Utf16>,
          Pointer<_AutoProxyOptions>,
          Pointer<_ProxyInfo>,
        ),
        int Function(
          Pointer<Void>,
          Pointer<Utf16>,
          Pointer<_AutoProxyOptions>,
          Pointer<_ProxyInfo>,
        )
      >('WinHttpGetProxyForUrl');
  final close = library
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('WinHttpCloseHandle');
  final free = DynamicLibrary.open('kernel32.dll')
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>),
        Pointer<Void> Function(Pointer<Void>)
      >('GlobalFree');
  final config = calloc<_UserProxy>();
  final info = calloc<_ProxyInfo>();
  final options = calloc<_AutoProxyOptions>();
  final agent = 'Vyrax'.toNativeUtf16();
  final url = uri.toString().toNativeUtf16();
  Pointer<Void> session = nullptr;
  try {
    if (getConfig(config) == 0) {
      throw const FormatException('Cannot read system proxy');
    }
    final manualProxy = _string(config.ref.proxy);
    final manualBypass = _string(config.ref.bypass);
    if (config.ref.configUrl != nullptr || config.ref.autoDetect != 0) {
      session = open(agent, 1, nullptr, nullptr, 0);
      if (session == nullptr) {
        throw const FormatException('Cannot resolve system proxy');
      }
      options.ref
        ..flags = config.ref.configUrl != nullptr ? 2 : 1
        ..detectFlags = 3
        ..configUrl = config.ref.configUrl;
      if (resolve(session, url, options, info) != 0) {
        if (info.ref.accessType == 1) return 'DIRECT';
        return windowsProxyDirective(
          uri,
          _string(info.ref.proxy),
          _string(info.ref.bypass),
        );
      }
      if (config.ref.configUrl != nullptr && manualProxy.isEmpty) {
        throw const FormatException('Cannot resolve configured PAC proxy');
      }
    }
    return windowsProxyDirective(uri, manualProxy, manualBypass);
  } finally {
    if (session != nullptr) close(session);
    for (final value in [
      config.ref.configUrl,
      config.ref.proxy,
      config.ref.bypass,
      info.ref.proxy,
      info.ref.bypass,
    ]) {
      if (value != nullptr) free(value.cast());
    }
    calloc.free(config);
    calloc.free(info);
    calloc.free(options);
    calloc.free(agent);
    calloc.free(url);
  }
}
