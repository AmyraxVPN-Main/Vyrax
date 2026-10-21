import 'dart:convert';

import 'package:fl_clash/common/vyrax_theme.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('theme preset survives serialization and can be cleared', () {
    const theme = ThemeProps(vyraxTheme: 'ocean');
    final restored = ThemeProps.fromJson(jsonDecode(jsonEncode(theme)));
    expect(restored.vyraxTheme, 'ocean');
    expect(restored.copyWith(vyraxTheme: null).vyraxTheme, isNull);
    expect(ThemeProps.fromJson({}).vyraxTheme, isNull);
  });

  test('all eight palettes apply only at their matching brightness', () {
    expect(vyraxPalettes, hasLength(8));
    for (final entry in vyraxPalettes.entries) {
      final scheme = ColorScheme.fromSeed(
        seedColor: entry.value.primary,
        brightness: entry.value.brightness,
      );
      final styled = withVyraxPalette(scheme, entry.key);
      expect(styled.primary, entry.value.primary);
      expect(styled.surface, entry.value.background);
      expect(styled.onSurface, entry.value.text);
      final opposite = ColorScheme.fromSeed(
        seedColor: entry.value.primary,
        brightness: entry.value.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      );
      expect(withVyraxPalette(opposite, entry.key), same(opposite));
    }
  });
}
