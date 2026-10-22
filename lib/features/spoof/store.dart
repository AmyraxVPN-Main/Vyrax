import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models.dart';

class SpoofSettings {
  final String? activeId;
  final SpoofCarrier carrier;
  final String fragment;
  final bool iranDirect;
  final bool mux;

  const SpoofSettings({
    required this.activeId,
    required this.carrier,
    required this.fragment,
    required this.iranDirect,
    required this.mux,
  });
}

class SpoofStore {
  static const _storage = FlutterSecureStorage();
  static const _bundlesKey = 'spoof-profiles-v1';
  static const _settingsKey = 'spoof-settings-v1';

  Future<List<SpoofBundle>> loadBundles() async {
    final raw = await _storage.read(key: _bundlesKey);
    if (raw == null || raw.isEmpty) return const [];
    List<SpoofBundle> bundles;
    try {
      final list = jsonDecode(raw) as List;
      bundles = [
        for (final item in list.whereType<Map>())
          if (item.containsKey('servers'))
            SpoofBundle.fromJson(Map<String, dynamic>.from(item)),
      ];
    } on FormatException {
      bundles = const [];
    }
    if (bundles.isEmpty) {
      // Legacy flat-profile payload (pre-bundle format) — discard it.
      await _storage.delete(key: _bundlesKey);
    }
    return bundles;
  }

  Future<void> saveBundles(List<SpoofBundle> bundles) => _storage.write(
    key: _bundlesKey,
    value: jsonEncode([for (final bundle in bundles) bundle.toJson()]),
  );

  Future<SpoofSettings> loadSettings() async {
    const fallback = SpoofSettings(
      activeId: null,
      carrier: SpoofCarrier.auto,
      fragment: 'full5',
      iranDirect: true,
      mux: false,
    );
    final raw = await _storage.read(key: _settingsKey);
    if (raw == null || raw.isEmpty) {
      return fallback;
    }
    Map<String, dynamic> json;
    try {
      json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } on FormatException {
      return fallback;
    }
    return SpoofSettings(
      activeId: json['activeId'] as String?,
      carrier: SpoofCarrierName.fromName('${json['carrier'] ?? 'auto'}'),
      fragment: '${json['fragment'] ?? 'full5'}',
      iranDirect: json['iranDirect'] as bool? ?? true,
      mux: json['mux'] as bool? ?? false,
    );
  }

  Future<void> saveSettings({
    String? activeId,
    SpoofCarrier? carrier,
    String? fragment,
    bool? iranDirect,
    bool? mux,
  }) async {
    final current = await loadSettings();
    final value = jsonEncode({
      'activeId': activeId ?? current.activeId,
      'carrier': (carrier ?? current.carrier).name,
      'fragment': fragment ?? current.fragment,
      'iranDirect': iranDirect ?? current.iranDirect,
      'mux': mux ?? current.mux,
    });
    await _storage.write(key: _settingsKey, value: value);
  }
}

final spoofStoreProvider = Provider<SpoofStore>((ref) => SpoofStore());
