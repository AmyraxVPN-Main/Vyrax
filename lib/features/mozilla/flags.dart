import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import 'api.dart';
import 'catalog.dart';

/// Country-flag store for Mozilla free-server proxies.
///
/// Detached from the proxy display name: [parseMozillaServers] records the
/// real ISO country code per edge host, this store keeps the host → code
/// mapping in the app data directory, and the proxies page renders it as a
/// real flag badge independently of the name text.
final mozillaFlags = MozillaFlags._();

/// Bumped whenever the host → country mapping changes so flag badges repaint.
final mozillaFlagsRevision = ValueNotifier<int>(0);

class MozillaFlags {
  MozillaFlags._();

  @visibleForTesting
  static Future<String?> Function() fileReader = _defaultRead;
  @visibleForTesting
  static Future<void> Function(String value) fileWriter = _defaultWrite;

  static const fileName = 'mozilla-countries.json';

  static Future<String?> _defaultRead() async {
    final file = File(join(await appPath.homeDirPath, fileName));
    if (await file.exists()) {
      return file.readAsString();
    }
    return null;
  }

  static Future<void> _defaultWrite(String value) async {
    await File(
      join(await appPath.homeDirPath, fileName),
    ).writeAsString(value, flush: true);
  }

  final Map<String, String> _byHost = {};
  bool _loaded = false;
  DateTime? _lastSync;

  @visibleForTesting
  void resetForTesting() {
    _byHost.clear();
    _loaded = false;
    _lastSync = null;
    mozillaFlagsRevision.value = 0;
  }

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    try {
      final value = await fileReader();
      final data = value == null || value.trim().isEmpty
          ? null
          : jsonDecode(value);
      if (data is Map) {
        data.forEach((key, code) {
          if (key is String &&
              code is String &&
              key.trim().isNotEmpty &&
              code.trim().isNotEmpty) {
            _byHost[key] = code;
          }
        });
      }
    } catch (_) {
      // A missing or broken cache must never surface in the UI.
    }
    mozillaFlagsRevision.value++;
  }

  Future<void> update(Map<String, String> codes) async {
    await load();
    var changed = false;
    codes.forEach((host, code) {
      if (_byHost[host] != code) {
        _byHost[host] = code;
        changed = true;
      }
    });
    if (changed) {
      await _persist();
    }
  }

  /// Rebuilds the mapping straight from the public Mozilla server list,
  /// throttled so opening the proxies page does not hammer the endpoint.
  Future<void> syncFromNetwork() async {
    final now = DateTime.now();
    if (_lastSync != null &&
        now.difference(_lastSync!) < const Duration(minutes: 15)) {
      return;
    }
    _lastSync = now;
    try {
      final countryCodes = <String, String>{};
      final response = await MozillaApi.send('servers');
      if (response.status != 200) {
        return;
      }
      parseMozillaServers(response.json(), countryCodes: countryCodes);
      await update(countryCodes);
    } catch (_) {
      // Flags stay name-only until the next successful sync.
    }
  }

  Future<void> _persist() async {
    try {
      await fileWriter(jsonEncode(_byHost));
      mozillaFlagsRevision.value++;
    } catch (_) {}
  }

  static final RegExp _nameSuffix = RegExp(r'\.fastly-masque\.net(:\d+)?$');

  /// Resolves the ISO country code behind a Mozilla proxy name, or null.
  @visibleForTesting
  String? codeForName(String name) {
    if (_byHost.isEmpty || !_nameSuffix.hasMatch(name)) {
      return null;
    }
    final host = name.split(' · ').last.split(':').first;
    return _byHost[host];
  }

  /// Country flag emoji for a Mozilla proxy name, respecting catchall REC.
  String? flagForName(String name) {
    final code = codeForName(name);
    if (code == null) {
      return null;
    }
    if (code.toUpperCase() == 'REC') {
      return '🌐';
    }
    return code.countryFlagEmoji;
  }

  /// True when the mozilla flag badge renders a badge for [name]; the
  /// generic name based badge must stay hidden so flags never duplicate.
  bool hasFlagForName(String name) => codeForName(name) != null;
}

/// Rounded flag badge rendered next to the Mozilla proxy name.
class MozillaFlagBadge extends StatelessWidget {
  final String proxyName;

  const MozillaFlagBadge(this.proxyName, {super.key});

  @override
  Widget build(BuildContext context) {
    final code = mozillaFlags.codeForName(proxyName);
    final flag = mozillaFlags.flagForName(proxyName);
    if (flag == null || code == null) {
      return const SizedBox.shrink();
    }
    const style = TextStyle(fontSize: 14, height: 1.2);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: code.toUpperCase() == 'REC'
          ? Text(
              flag,
              style: style.copyWith(fontFamily: FontFamily.twEmoji.value),
            )
          : CountryFlagEmoji(code, style: style),
    );
  }
}
