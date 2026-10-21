import 'package:material_ui/material_ui.dart';

typedef VyraxPalette = ({
  Color background,
  Color surface,
  Color raised,
  Color text,
  Color muted,
  Color primary,
  Color secondary,
  Brightness brightness,
});

const vyraxPalettes = <String, VyraxPalette>{
  'dark': (
    background: Color(0xff141212),
    surface: Color(0xff201e1d),
    raised: Color(0xff383434),
    text: Color(0xffe8e1e1),
    muted: Color(0xffbcb0b1),
    primary: Color(0xffdac2c5),
    secondary: Color(0xffa3bd76),
    brightness: Brightness.dark,
  ),
  'crimson': (
    background: Color(0xff0a0708),
    surface: Color(0xff1c1416),
    raised: Color(0xff261b1e),
    text: Color(0xfff6eced),
    muted: Color(0xffb1999c),
    primary: Color(0xffff3b4f),
    secondary: Color(0xffff7a59),
    brightness: Brightness.dark,
  ),
  'black': (
    background: Color(0xff000000),
    surface: Color(0xff121212),
    raised: Color(0xff1a1a1a),
    text: Color(0xfff2f2f2),
    muted: Color(0xff9a9a9a),
    primary: Color(0xffffffff),
    secondary: Color(0xffd9d9d9),
    brightness: Brightness.dark,
  ),
  'ocean': (
    background: Color(0xff060a12),
    surface: Color(0xff131b29),
    raised: Color(0xff1a2434),
    text: Color(0xffe8f0fb),
    muted: Color(0xff8fa3bf),
    primary: Color(0xff3b9bff),
    secondary: Color(0xff22d3ee),
    brightness: Brightness.dark,
  ),
  'violet': (
    background: Color(0xff0b0911),
    surface: Color(0xff1b1626),
    raised: Color(0xff231d31),
    text: Color(0xfff0ebfb),
    muted: Color(0xffa79bbd),
    primary: Color(0xffa371f7),
    secondary: Color(0xffd58cff),
    brightness: Brightness.dark,
  ),
  'gold': (
    background: Color(0xff0a0906),
    surface: Color(0xff1b1913),
    raised: Color(0xff24211a),
    text: Color(0xfff7f1e3),
    muted: Color(0xffb2a88f),
    primary: Color(0xffe8b931),
    secondary: Color(0xffffd166),
    brightness: Brightness.dark,
  ),
  'rose': (
    background: Color(0xff0f090c),
    surface: Color(0xff21181c),
    raised: Color(0xff2a1f24),
    text: Color(0xfffbecf1),
    muted: Color(0xffbb9ca7),
    primary: Color(0xffff5c8a),
    secondary: Color(0xffff8fab),
    brightness: Brightness.dark,
  ),
  'light': (
    background: Color(0xfffff8f9),
    surface: Color(0xfff5edef),
    raised: Color(0xffeadddf),
    text: Color(0xff2d2227),
    muted: Color(0xff73616a),
    primary: Color(0xff875066),
    secondary: Color(0xff65823b),
    brightness: Brightness.light,
  ),
};

ColorScheme withVyraxPalette(ColorScheme scheme, String? id) {
  final palette = vyraxPalettes[id];
  if (palette == null || palette.brightness != scheme.brightness) return scheme;
  Color ink(Color color) =>
      ThemeData.estimateBrightnessForColor(color) == Brightness.dark
      ? const Color(0xffffffff)
      : const Color(0xff141212);
  final primaryContainer = Color.alphaBlend(
    palette.primary.withValues(alpha: 0.20),
    palette.surface,
  );
  final secondaryContainer = Color.alphaBlend(
    palette.secondary.withValues(alpha: 0.20),
    palette.surface,
  );
  return scheme.copyWith(
    primary: palette.primary,
    onPrimary: ink(palette.primary),
    secondary: palette.secondary,
    onSecondary: ink(palette.secondary),
    primaryContainer: primaryContainer,
    onPrimaryContainer: palette.text,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: palette.text,
    surface: palette.background,
    onSurface: palette.text,
    onSurfaceVariant: palette.muted,
    surfaceContainerLowest: palette.background,
    surfaceContainerLow: palette.surface,
    surfaceContainer: palette.surface,
    surfaceContainerHigh: palette.raised,
    surfaceContainerHighest: palette.raised,
  );
}
