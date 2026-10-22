import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter/material.dart';

class CountryFlagEmoji extends StatelessWidget {
  final String code;
  final TextStyle? style;

  const CountryFlagEmoji(this.code, {this.style, super.key});

  Widget _tricolor(double fontSize) {
    return Container(
      width: fontSize * 1.36,
      height: fontSize,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0x33000000)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: ColoredBox(color: Color(0xFF239F40))),
          Spacer(),
          Expanded(child: ColoredBox(color: Color(0xFFDA0000))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style?.copyWith(fontFamily: FontFamily.twEmoji.value);
    final fontSize = effectiveStyle?.fontSize ?? 14;
    if (code.toUpperCase() == 'IR') {
      return _tricolor(fontSize);
    }
    return Text(code.countryFlagEmoji, style: effectiveStyle);
  }
}
