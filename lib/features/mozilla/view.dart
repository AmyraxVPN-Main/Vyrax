import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/yaml_writer.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'accounts.dart';
import 'api.dart';
import 'catalog.dart';
import 'provider.dart';

String mozillaErrorText(MozillaError error, AppLocalizations l) =>
    switch (error) {
      MozillaError.network => l.mozillaNetworkError,
      MozillaError.credentials => l.mozillaCredentialsError,
      MozillaError.verification => l.mozillaCodeError,
      MozillaError.challenge => l.mozillaChallengeError,
      MozillaError.eligibility => l.mozillaEligibilityError,
      MozillaError.auth => l.mozillaAuthError,
      MozillaError.quota => l.mozillaQuotaError,
      MozillaError.storage => l.mozillaStorageError,
      MozillaError.accounts => l.mozillaAccountsError,
      MozillaError.noServers => l.mozillaServersError,
      MozillaError.notActivated => l.mozillaActivationError,
      MozillaError.service => l.mozillaServiceError,
    };

Future<void> showMozillaDialog(BuildContext context) => showDialog<void>(
  context: context,
  useRootNavigator: false,
  barrierColor: context.colorScheme.modalScrim,
  builder: (context) => Dialog(
    insetPadding: const EdgeInsets.all(24),
    shape: AppShape.xxl.copyWith(
      side: BorderSide(color: context.colorScheme.outlineVariant),
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 560,
        maxHeight: (MediaQuery.sizeOf(context).height - 48).clamp(
          1,
          double.infinity,
        ),
      ),
      child: const KeyboardInsetHold(child: MozillaView(modal: true)),
    ),
  ),
);

class MozillaView extends ConsumerStatefulWidget {
  const MozillaView({super.key, this.modal = false});
  final bool modal;
  @override
  ConsumerState<MozillaView> createState() => _MozillaViewState();
}

class _MozillaViewState extends ConsumerState<MozillaView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  late final MozillaAccounts _accounts;
  bool _busy = true;
  bool _login = false;
  bool _guide = false;
  String? _error;
  String? _notice;
  String? _armedAccount;
  Timer? _armTimer;

  @override
  void initState() {
    super.initState();
    _accounts = ref.read(mozillaAccountsProvider);
    unawaited(
      _run(() async {
        await _accounts.initialize();
        if (_accounts.signedIn) await _accounts.refresh();
      }, initializing: true),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    _armTimer?.cancel();
    _accounts.cancelVerification();
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function() action, {
    bool initializing = false,
  }) async {
    if (_busy && !initializing) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is MozillaException
              ? mozillaErrorText(error.reason, context.appLocalizations)
              : context.appLocalizations.mozillaServiceError;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _signIn() => _run(() async {
    final password = _password.text;
    _password.clear();
    await _accounts.signIn(_email.text, password);
    if (mounted && _login && _accounts.signedIn) {
      setState(() {
        _login = false;
      });
      await _accounts.refresh();
    }
  });

  Future<void> _verify() => _run(() async {
    await _accounts.verify(_code.text);
    if (!mounted || !_login || !_accounts.signedIn) return;
    _code.clear();
    setState(() {
      _login = false;
    });
    await _accounts.refresh();
  });

  void _back() {
    _accounts.cancelVerification();
    _password.clear();
    _code.clear();
    setState(() {
      _login = false;
      _guide = false;
      _error = null;
      _notice = null;
    });
  }

  Future<void> _useServers() => _run(() async {
    await _accounts.proxyPass();
    final servers = await _accounts.servers();
    if (!mounted) return;
    final label = context.appLocalizations.mozillaProfile;
    final existing = ref
        .read(profilesProvider)
        .where((p) => p.id == kMozillaSystemProfileId)
        .firstOrNull;
    final profile =
        existing ??
        Profile.normal(label: label).copyWith(
          id: kMozillaSystemProfileId,
          order: -1,
        );
    final core = ref.read(coreHandlerProvider);
    final saved = await profile
        .copyWith(autoUpdate: false)
        .saveFile(
          Uint8List.fromList(utf8.encode(writeYaml(mozillaProfile(servers)))),
          validate: (path, _) => core.validateConfig(path),
        );
    if (!mounted) return;
    ref.read(profilesActionProvider.notifier).setProfileAndAutoApply(saved);
    if (!mounted) return;
    ref.read(currentProfileIdProvider.notifier).value = saved.id;
    setState(() {
      _notice = context.appLocalizations.mozillaImported;
    });
  });

  Future<void> _remove(String email) async {
    _armTimer?.cancel();
    if (_armedAccount != email) {
      setState(() => _armedAccount = email);
      _armTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _armedAccount = null);
      });
      return;
    }
    setState(() => _armedAccount = null);
    await _run(() => _accounts.removeAccount(email));
  }

  Future<void> _open(String url) => _run(() async {
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      throw const MozillaException(MozillaError.network);
    }
  });

  Widget _button(
    String text,
    VoidCallback onPressed, {
    bool primary = false,
    bool enabled = true,
    Glyph? icon,
  }) {
    const style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(double.infinity, 42)),
      shape: WidgetStatePropertyAll(AppShape.full),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
    final label = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          GlyphIcon(icon, size: 18, fill: 1),
          const SizedBox(width: 8),
        ],
        Flexible(child: Text(text, textAlign: TextAlign.center)),
      ],
    );
    return primary
        ? FilledButton(
            style: style,
            onPressed: _busy || !enabled ? null : onPressed,
            child: label,
          )
        : FilledButton.tonal(
            style: style,
            onPressed: _busy || !enabled ? null : onPressed,
            child: label,
          );
  }

  Widget _panel(Widget child, {bool selected = false, bool compact = false}) =>
      Container(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 2)
            : const EdgeInsets.all(16),
        decoration: ShapeDecoration(
          color: context.colorScheme.surfaceContainerLow,
          shape: AppShape.lg.copyWith(
            side: BorderSide(
              color: selected
                  ? context.colorScheme.primary
                  : context.colorScheme.outlineVariant,
            ),
          ),
        ),
        child: child,
      );

  List<Widget> _guideContent(AppLocalizations l) => [
    Text(l.mozillaIntro, style: context.textTheme.bodySmall),
    ...l.mozillaGuideSteps.split('\n\n').indexed.map((step) {
      final lines = step.$2.split('\n');
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            height: 42,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: ShapeDecoration(
                    shape: AppShape.full.copyWith(
                      side: BorderSide(
                        color: context.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: GlyphIcon(
                    [
                      AppGlyphs.mail,
                      AppGlyphs.shieldCheck,
                      AppGlyphs.gift,
                      AppGlyphs.proxies,
                    ][step.$1.clamp(0, 3)],
                    size: 19,
                    color: context.colorScheme.primary,
                  ),
                ),
                PositionedDirectional(
                  end: 0,
                  bottom: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: context.colorScheme.primaryContainer,
                      shape: AppShape.full,
                    ),
                    child: Text(
                      '${step.$1 + 1}',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lines.first, style: context.textTheme.titleSmall),
                const SizedBox(height: 5),
                Text(
                  lines.skip(1).join('\n'),
                  style: context.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      );
    }),
    _panel(
      Text(
        '${l.mozillaAllowanceTitle}\n\n${l.mozillaAllowance}\n\n${l.mozillaTcpOnly}',
        style: context.textTheme.bodySmall,
      ),
    ),
    _button(
      l.mozillaCreateAccount,
      () => unawaited(_open('https://accounts.firefox.com/')),
      icon: AppGlyphs.openExternal,
    ),
    _button(
      l.mozillaOfficialHelp,
      () =>
          unawaited(_open('https://support.mozilla.org/products/firefox-vpn')),
      icon: AppGlyphs.openExternal,
    ),
  ];

  List<Widget> _loginContent(AppLocalizations l) => [
    if (!_accounts.needsVerification)
      Text(l.mozillaVerificationHint, style: context.textTheme.bodySmall),
    if (_accounts.needsVerification) ...[
      Text(l.mozillaVerificationHint),
      TextField(
        controller: _code,
        enabled: !_busy,
        maxLength: 16,
        autofillHints: const [AutofillHints.oneTimeCode],
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(
          labelText: l.mozillaVerificationCode,
          counterText: '',
        ),
        onSubmitted: (_) => unawaited(_verify()),
      ),
      _button(l.mozillaVerify, () => unawaited(_verify()), primary: true),
    ] else ...[
      TextField(
        controller: _email,
        enabled: !_busy,
        maxLength: 254,
        keyboardType: TextInputType.emailAddress,
        textDirection: TextDirection.ltr,
        autofillHints: const [AutofillHints.username],
        autocorrect: false,
        decoration: InputDecoration(labelText: l.mozillaEmail, counterText: ''),
      ),
      TextField(
        controller: _password,
        enabled: !_busy,
        maxLength: 4096,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: l.mozillaPassword,
          counterText: '',
        ),
        onSubmitted: (_) => unawaited(_signIn()),
      ),
      Text(l.mozillaPrivacy, style: context.textTheme.bodySmall),
      _button(l.mozillaSignIn, () => unawaited(_signIn()), primary: true),
    ],
    _button(l.cancel, _back),
  ];

  List<Widget> _accountContent(AppLocalizations l) {
    final quota = _accounts.quota;
    final limit = quota['limit'] as num?;
    final remaining = quota['remaining'] as num?;
    final reset = quota['reset'] as num?;
    String amount(num bytes) => '${(bytes / 1073741824).toStringAsFixed(2)} GB';
    return [
      Text(l.mozillaIntro, style: context.textTheme.bodySmall),
      if (_accounts.signedIn) ...[
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.mozillaAllowanceTitle,
                      style: context.textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: l.update,
                    onPressed: _busy
                        ? null
                        : () => unawaited(_run(() => _accounts.refresh())),
                    icon: const GlyphIcon(AppGlyphs.refresh, size: 18),
                  ),
                ],
              ),
              Text(
                _accounts.email,
                textDirection: TextDirection.ltr,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodySmall,
              ),
              if (limit != null && limit > 0 && remaining != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        amount(remaining.clamp(0, double.infinity)),
                        textDirection: TextDirection.ltr,
                        style: context.textTheme.headlineSmall?.copyWith(
                          color: context.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      l.mozillaRemaining,
                      style: context.textTheme.bodySmall,
                    ),
                  ],
                ),
                LinearProgressIndicator(
                  value: (remaining / limit).clamp(0.0, 1.0),
                  minHeight: 5,
                ),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      '${l.usedTraffic}: ${amount((limit - remaining).clamp(0, double.infinity))}',
                      style: context.textTheme.labelSmall,
                    ),
                    Text(
                      '${l.total}: ${amount(limit)}',
                      style: context.textTheme.labelSmall,
                    ),
                  ],
                ),
              ] else
                Text(l.mozillaQuotaUnknown, style: context.textTheme.bodySmall),
              if (reset != null && reset > 0)
                Text(
                  '${l.mozillaReset}: ${DateTime.fromMillisecondsSinceEpoch(reset.toInt() * 1000).toLocal()}',
                  style: context.textTheme.labelSmall,
                ),
              Text(l.mozillaQuotaSnapshot, style: context.textTheme.labelSmall),
            ],
          ),
        ),
        Text(l.mozillaAccounts, style: context.textTheme.titleMedium),
        for (final email in _accounts.emails)
          _panel(
            selected: email == _accounts.email,
            compact: true,
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    customBorder: AppShape.md,
                    onTap: _busy || email == _accounts.email
                        ? null
                        : () => unawaited(
                            _run(() async {
                              await _accounts.switchAccount(email);
                              await _accounts.refresh();
                            }),
                          ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              email,
                              textDirection: TextDirection.ltr,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.bodySmall,
                            ),
                          ),
                          if (email == _accounts.email)
                            const GlyphIcon(AppGlyphs.check, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_armedAccount == email)
                  TextButton(
                    onPressed: _busy ? null : () => unawaited(_remove(email)),
                    child: Text(
                      l.confirm,
                      style: TextStyle(color: context.colorScheme.error),
                    ),
                  )
                else
                  IconButton(
                    tooltip: l.mozillaRemoveAccount,
                    onPressed: _busy ? null : () => unawaited(_remove(email)),
                    icon: const GlyphIcon(AppGlyphs.delete, size: 16),
                  ),
              ],
            ),
          ),
        if (_accounts.activated)
          _button(
            l.mozillaUseServers,
            () => unawaited(_useServers()),
            primary: true,
            enabled: remaining != 0,
            icon: AppGlyphs.proxies,
          )
        else
          _button(
            l.mozillaActivate,
            () => unawaited(_run(() => _accounts.refresh(activate: true))),
            primary: true,
            icon: AppGlyphs.gift,
          ),
      ],
      _button(
        _accounts.signedIn ? l.mozillaAddAccount : l.mozillaSignIn,
        () {
          _email.clear();
          setState(() {
            _login = true;
            _error = null;
          });
        },
        primary: !_accounts.signedIn,
        icon: _accounts.signedIn ? AppGlyphs.add : AppGlyphs.account,
      ),
      Text(l.mozillaSwitchHint, style: context.textTheme.bodySmall),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final content = ListenableBuilder(
      listenable: _accounts,
      builder: (context, _) => Center(
        heightFactor: widget.modal ? 1 : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            shrinkWrap: widget.modal,
            padding: EdgeInsets.fromLTRB(
              22,
              widget.modal ? 2 : context.contentTopPadding,
              22,
              24 + BottomInsetScope.of(context),
            ),
            children: [
              if (_login || _guide) ...[
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: _back,
                    icon: const GlyphIcon(AppGlyphs.arrowBack, size: 16),
                    label: Text(l.back),
                  ),
                ),
                const Divider(),
                const SizedBox(height: 16),
              ],
              if (!_login && !_guide) ...[
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _guide = true;
                          _error = null;
                          _notice = null;
                        }),
                  child: Row(
                    children: [
                      const GlyphIcon(AppGlyphs.bookOpen, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l.mozillaGuide)),
                      const GlyphIcon(AppGlyphs.chevronForward, size: 16),
                    ],
                  ),
                ),
                const Divider(),
                const SizedBox(height: 16),
              ],
              ...(_guide
                      ? _guideContent(l)
                      : _login
                      ? _loginContent(l)
                      : _accountContent(l))
                  .expand((widget) => [widget, const SizedBox(height: 16)]),
              if (_busy) const LinearProgressIndicator(),
              if (_notice case final notice?) _panel(Text(notice)),
              if (_error case final error?) ...[
                _panel(
                  Text(
                    error,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _button(
                  l.mozillaOpenAccount,
                  () => unawaited(_open('https://accounts.firefox.com/')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!widget.modal) {
      return CommonScaffold(title: l.mozillaTitle, body: content);
    }
    return PopScope(
      canPop: !_login && !_guide,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _back();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(22, 14, 12, 8),
            child: Row(
              children: [
                GlyphIcon(
                  AppGlyphs.gift,
                  size: 19,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _guide ? l.mozillaGuide : l.mozillaTitle,
                    style: context.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: l.close,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const GlyphIcon(AppGlyphs.close, size: 16),
                ),
              ],
            ),
          ),
          Flexible(fit: FlexFit.loose, child: content),
        ],
      ),
    );
  }
}
