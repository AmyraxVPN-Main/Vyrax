import 'dart:convert';

import 'package:fl_clash/features/mozilla/flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var stored = <String, String>{};
  setUp(() {
    stored = {};
    mozillaFlags.resetForTesting();
    MozillaFlags.fileReader = () async {
      if (stored.isEmpty) {
        return null;
      }
      return const JsonEncoder().convert(stored);
    };
    MozillaFlags.fileWriter = (value) async {
      final data = const JsonDecoder().convert(value) as Map<String, dynamic>;
      stored = data.cast<String, String>();
    };
  });

  test('country codes persist per edge host and survive reload', () async {
    await mozillaFlags.update({
      'sbsp209.m1.fastly-masque.net': 'BR',
      'cph332.m1.fastly-masque.net': 'DK',
      'edge.m1.fastly-masque.net': 'REC',
    });
    expect(stored, containsPair('sbsp209.m1.fastly-masque.net', 'BR'));
    mozillaFlags.resetForTesting();
    await mozillaFlags.load();
    expect(
      mozillaFlags.codeForName(
        'Brazil · São Paulo · sbsp209.m1.fastly-masque.net:2499',
      ),
      'BR',
    );
    expect(
      mozillaFlags.codeForName('Denmark · cph332.m1.fastly-masque.net:2499'),
      'DK',
    );
  });

  test('names outside the Mozilla edge never resolve to a flag', () async {
    await mozillaFlags.update({'sbsp209.m1.fastly-masque.net': 'BR'});
    expect(mozillaFlags.codeForName('Google · 1.2.3.4:443'), isNull);
    expect(mozillaFlags.codeForName('FASTEST'), isNull);
    expect(
      mozillaFlags.flagForName('Example · evil.fastly-masque.network:443'),
      isNull,
    );
  });

  testWidgets('badge renders the real country flag and catchall globe', (
    tester,
  ) async {
    await mozillaFlags.update({
      'sbsp209.m1.fastly-masque.net': 'BR',
      'edge.m1.fastly-masque.net': 'REC',
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: MozillaFlagBadge(
          'Brazil · São Paulo · sbsp209.m1.fastly-masque.net:2499',
        ),
      ),
    );
    expect(find.text('🇧🇷', findRichText: true), findsOneWidget);
    await tester.pumpWidget(
      const MaterialApp(
        home: MozillaFlagBadge('Recommended · edge.m1.fastly-masque.net:2499'),
      ),
    );
    expect(find.text('🌐', findRichText: true), findsOneWidget);
  });

  testWidgets('Iran renders as a plain green-white-red tricolor', (
    tester,
  ) async {
    await mozillaFlags.update({'irn301.m1.fastly-masque.net': 'IR'});
    await tester.pumpWidget(
      const MaterialApp(
        home: MozillaFlagBadge(
          'Iran · Tehran · irn301.m1.fastly-masque.net:2499',
        ),
      ),
    );
    final boxes = tester.widgetList<ColoredBox>(
      find.byType(ColoredBox),
    ).map((box) => box.color).toSet();
    expect(boxes, containsAll(const [Color(0xFF239F40), Color(0xFFDA0000)]));
    expect(find.textContaining('🇮', findRichText: true), findsNothing);
  });

  testWidgets('badge collapses for names without a location', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MozillaFlagBadge('bogus')));
    expect(find.text('🇧🇷', findRichText: true), findsNothing);
  });
}
