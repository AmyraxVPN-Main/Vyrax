import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('iran tricolor paints', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ColoredBox(
          color: Color(0xFF202124),
          child: Center(
            child: CountryFlagEmoji(
              'IR',
              style: TextStyle(fontSize: 14, height: 1.2),
            ),
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byType(CountryFlagEmoji));
    expect(size.width, closeTo(19.0, 0.5));
    expect(size.height, closeTo(14.0, 0.5));
    await expectLater(
      find.byType(CountryFlagEmoji),
      matchesGoldenFile('goldens/country_flag_ir.png'),
    );
  });
}
