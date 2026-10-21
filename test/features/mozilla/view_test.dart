import 'dart:async';

import 'package:fl_clash/features/mozilla/accounts.dart';
import 'package:fl_clash/features/mozilla/api.dart';
import 'package:fl_clash/features/mozilla/provider.dart';
import 'package:fl_clash/features/mozilla/view.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/test_app.dart';

class _Vault implements MozillaVault {
  Future<String?> Function() load = () async => null;
  @override
  Future<String?> read() => load();
  @override
  Future<void> write(String value) async {}
}

class _DelayedLogin extends MozillaApi {
  final reply = Completer<Map<String, dynamic>>();
  bool started = false;
  @override
  Future<Map<String, dynamic>> login(String email, String password) {
    started = true;
    return reply.future;
  }
}

void main() {
  testWidgets('back cancels a pending login without saving its late reply', (
    tester,
  ) async {
    final api = _DelayedLogin();
    var saved = false;
    final vault = _Vault();
    final accounts = MozillaAccounts(
      vault: vault,
      beforeAccountChange: () async {
        saved = true;
      },
      api: api,
    );
    addTearDown(accounts.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mozillaAccountsProvider.overrideWithValue(accounts)],
        child: const TestApp(child: MozillaView()),
      ),
    );
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(tester.element(find.byType(MozillaView)));
    await tester.tap(find.text(l.mozillaSignIn));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'tester@example.com');
    await tester.enterText(find.byType(TextField).last, 'sample-password');
    await tester.ensureVisible(find.text(l.mozillaSignIn));
    await tester.tap(find.text(l.mozillaSignIn));
    await tester.pump();
    expect(api.started, isTrue);
    await tester.ensureVisible(find.text(l.back));
    await tester.tap(find.text(l.back));
    await tester.pump();
    api.reply.complete({'sessionToken': 'ab' * 32, 'verified': true});
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(accounts.signedIn, isFalse);
    expect(saved, isFalse);
    expect(find.text(l.mozillaAuthError), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(900, 620), const Size(320, 568)]) {
    testWidgets('free server dialog stays centered and fits $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final accounts = MozillaAccounts(
        vault: _Vault(),
        beforeAccountChange: () async {},
      );
      addTearDown(accounts.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [mozillaAccountsProvider.overrideWithValue(accounts)],
          child: TestApp(
            locale: const Locale('fa'),
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => unawaited(showMozillaDialog(context)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(MozillaView));
      expect(rect.center.dx, closeTo(size.width / 2, 1));
      expect(rect.width, lessThanOrEqualTo(560));
      final l = AppLocalizations.of(tester.element(find.byType(MozillaView)));
      await tester.scrollUntilVisible(
        find.text(l.mozillaSignIn),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text(l.mozillaSignIn));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text(l.cancel),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(l.cancel));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byTooltip(l.close));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });
  }

  Future<void> pump(
    WidgetTester tester,
    MozillaAccounts accounts,
    Locale locale,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mozillaAccountsProvider.overrideWithValue(accounts)],
        child: TestApp(locale: locale, child: const MozillaView()),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final locale in [const Locale('en'), const Locale('fa')]) {
    testWidgets('login and guide fit a narrow $locale screen', (tester) async {
      final accounts = MozillaAccounts(
        vault: _Vault(),
        beforeAccountChange: () async {},
      );
      addTearDown(accounts.dispose);
      await pump(tester, accounts, locale);
      final l = AppLocalizations.of(tester.element(find.byType(MozillaView)));
      final login = find.text(l.mozillaSignIn);
      await tester.ensureVisible(login);
      await tester.tap(login);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields.last.obscureText, isTrue);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text(l.cancel));
      await tester.tap(find.text(l.cancel));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(l.mozillaGuide));
      await tester.tap(find.text(l.mozillaGuide));
      await tester.pumpAndSettle();
      expect(find.text(l.mozillaGuideSteps.split('\n').first), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is GlyphIcon && widget.glyph == AppGlyphs.mail,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'storage failure is localized and loading can finish after disposal',
    (tester) async {
      final vault = _Vault()
        ..load = () async => throw StateError('unavailable');
      final accounts = MozillaAccounts(
        vault: vault,
        beforeAccountChange: () async {},
      );
      addTearDown(accounts.dispose);
      await pump(tester, accounts, const Locale('en'));
      expect(
        find.text(AppLocalizations.current.mozillaStorageError),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      final pending = Completer<String?>();
      final slow = MozillaAccounts(
        vault: _Vault()..load = () => pending.future,
        beforeAccountChange: () async {},
      );
      addTearDown(slow.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [mozillaAccountsProvider.overrideWithValue(slow)],
          child: const TestApp(child: MozillaView()),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete(null);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
