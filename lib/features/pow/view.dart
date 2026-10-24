import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'models.dart' as pow_models;
import 'provider.dart';
import 'status.dart';

Future<void> showPowDialog(BuildContext context) => showDialog<void>(
  context: context,
  useRootNavigator: false,
  barrierColor: context.colorScheme.modalScrim,
  builder: (context) => Dialog(
    insetPadding: const EdgeInsets.all(24),
    clipBehavior: Clip.antiAlias,
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
      child: const KeyboardInsetHold(child: PowView(modal: true)),
    ),
  ),
);

/// One-shot connect flow shown when the run button brings up a down Vyrax
/// Free tunnel: live connection steps, a green check with a Done button on
/// success, and a retry on failure. Closing the dialog never cancels the
/// tunnel it started.
Future<void> showPowConnectFlow(BuildContext context) => showDialog<void>(
  context: context,
  useRootNavigator: false,
  barrierDismissible: false,
  barrierColor: context.colorScheme.modalScrim,
  builder: (dialogContext) => Dialog(
    insetPadding: const EdgeInsets.all(24),
    clipBehavior: Clip.antiAlias,
    shape: AppShape.xxl.copyWith(
      side: BorderSide(color: dialogContext.colorScheme.outlineVariant),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: const PowConnectFlowView(),
    ),
  ),
);

class PowConnectFlowView extends ConsumerStatefulWidget {
  const PowConnectFlowView({super.key});

  @override
  ConsumerState<PowConnectFlowView> createState() => _PowConnectFlowViewState();
}

class _PowConnectFlowViewState extends ConsumerState<PowConnectFlowView>
    with SingleTickerProviderStateMixin {
  bool _started = false;
  bool _celebrating = false;
  AnimationController? _check;
  Animation<double>? _checkScale;

  static const _celebrationDuration = Duration(milliseconds: 1600);

  @override
  void initState() {
    super.initState();
    final animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: 0,
    );
    _check = animation;
    _checkScale = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutBack,
    ).drive(Tween(begin: 0.4, end: 1.0));
  }

  @override
  void dispose() {
    _check?.dispose();
    _check = null;
    super.dispose();
  }

  void _begin() {
    if (_started) return;
    _started = true;
    unawaited(_runFlow());
  }

  Future<void> _runFlow() async {
    final controller = ref.read(powControllerProvider);
    // A tunnel the startup reconciliation adopted (or that is already
    // dialling, e.g. a background recovery the run button joined) is the
    // connection the user asked for — never redial it.
    if (!controller.connected && !controller.busy) {
      await controller.connect();
    }
    // A background recovery keeps `busy` until it settles; the dialog just
    // mirrors its outcome instead of racing it with a second dial.
    while (mounted && controller.busy && !controller.connected) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (!mounted) return;
    // The tunnel is up; make sure the core is running so the connection the
    // user asked for (the run button) is really serving traffic now.
    final running = ref.read(isStartProvider);
    if (controller.connected && !running) {
      await ref
          .read(setupActionProvider.notifier)
          .setRunning(true, initialize: !ref.read(initProvider));
    }
    if (!mounted) return;
    if (controller.connected) {
      _celebrateAndClose();
    }
  }

  /// Plays the green check and closes the dialog on its own — the flow is
  /// done, there is nothing for the user to wait for anymore.
  void _celebrateAndClose() {
    if (_celebrating || !mounted) return;
    _celebrating = true;
    _check?.forward(from: 0);
    Future<void>.delayed(_celebrationDuration, () {
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }

  void _retry() {
    _started = false;
    _celebrating = false;
    _begin();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(powControllerProvider);
    _begin();
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final l = context.appLocalizations;
        final success = controller.connected && !controller.busy;
        if (success) {
          // Covers every path that ends connected (own connect, adopted
          // leftover tunnel, background recovery): play the check and let
          // the dialog close itself.
          _celebrateAndClose();
        }
        final failed = !success && !controller.busy &&
            !controller.recovering &&
            (controller.failure?.isNotEmpty == true);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(22, 14, 12, 8),
              child: Row(
                children: [
                  GlyphIcon(
                    AppGlyphs.sparkle,
                    size: 19,
                    color: context.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(l.powTitle, style: context.textTheme.titleSmall),
                  ),
                  IconButton(
                    tooltip: l.close,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const GlyphIcon(AppGlyphs.close, size: 16),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 14,
                children: [
                  if (success) ...[
                    Row(
                      spacing: 10,
                      children: [
                        ScaleTransition(
                          scale: _checkScale ?? const AlwaysStoppedAnimation(1),
                          child: GlyphIcon(
                            AppGlyphs.checkCircle,
                            size: 26,
                            color: context.colorScheme.primary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            l.powFlowConnected,
                            style: context.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l.powFlowDone),
                    ),
                  ] else if (failed) ...[
                    Row(
                      spacing: 10,
                      children: [
                        GlyphIcon(
                          AppGlyphs.error,
                          size: 26,
                          color: context.colorScheme.error,
                        ),
                        Expanded(
                          child: Text(
                            l.powFlowFailed,
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: context.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (controller.failure?.isNotEmpty == true)
                      Text(
                        controller.failure!,
                        textDirection: TextDirection.ltr,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Row(
                      spacing: 10,
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(l.close),
                          ),
                        ),
                        Expanded(
                          child: FilledButton(
                            onPressed: _retry,
                            child: Text(l.powFlowRetry),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // One spinner only: the header carries the live status
                    // (the newest step text), older steps follow muted.
                    Row(
                      spacing: 10,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            controller.status.detail.isNotEmpty
                                ? controller.status.detail
                                : (controller.status.steps.isEmpty
                                      ? l.powFlowConnecting
                                      : controller.status.steps.last.text),
                            textDirection: TextDirection.ltr,
                            style: context.textTheme.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (controller.status.steps.isNotEmpty)
                      Column(
                        spacing: 4,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final step in controller.status.steps
                              .toList()
                              .reversed
                              .take(controller.status.detail.isNotEmpty ? 3 : 2))
                            _FlowStepRow(step: step),
                        ],
                      ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

class _FlowStepRow extends StatelessWidget {
  const _FlowStepRow({required this.step});

  final PowStep step;

  @override
  Widget build(BuildContext context) {
    final color = switch (step.state) {
      PowStepState.done => context.colorScheme.primary,
      PowStepState.failed => context.colorScheme.error,
      PowStepState.running => context.colorScheme.onSurfaceVariant,
    };
    final icon = switch (step.state) {
      PowStepState.done => AppGlyphs.shieldCheck,
      PowStepState.failed => AppGlyphs.error,
      PowStepState.running => AppGlyphs.settings,
    };
    return Row(
      spacing: 10,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: GlyphIcon(icon, size: 14, color: color),
        ),
        Expanded(
          child: Text(
            step.text,
            textDirection: TextDirection.ltr,
            style: context.textTheme.bodySmall?.copyWith(
              color: step.state == PowStepState.failed ? color : null,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

class PowView extends ConsumerStatefulWidget {
  const PowView({super.key, this.modal = false});

  final bool modal;

  @override
  ConsumerState<PowView> createState() => _PowViewState();
}

class _PowViewState extends ConsumerState<PowView> {
  bool _showLogs = false;

  Future<void> _connect() => ref.read(powControllerProvider).connect();

  Future<void> _disconnect() => ref.read(powControllerProvider).disconnect();

  Future<void> _forgetNetworks() =>
      ref.read(powControllerProvider).forgetNetworkMemory();

  Future<void> _removeVyraxFree() async {
    final l = context.appLocalizations;
    final confirmed = await dialogs.showMessage(
      title: l.powRemove,
      message: TextSpan(text: l.powRemoveDesc),
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(powControllerProvider).removeVyraxFree();
  }

  Widget _panel(Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: ShapeDecoration(
      color: context.colorScheme.surfaceContainerLow,
      shape: AppShape.lg.copyWith(
        side: BorderSide(color: context.colorScheme.outlineVariant),
      ),
    ),
    child: child,
  );

  String _regionLabel(
    AppLocalizations l,
    pow_models.PowSettings settings,
    String code,
  ) {
    if (code.isEmpty) return l.powRegionAuto;
    return pow_models.regionName(code);
  }

  Widget _stepRow(PowStep step) {
    final color = switch (step.state) {
      PowStepState.done => context.colorScheme.primary,
      PowStepState.failed => context.colorScheme.error,
      PowStepState.running => context.colorScheme.onSurfaceVariant,
    };
    final icon = switch (step.state) {
      PowStepState.done => AppGlyphs.shieldCheck,
      PowStepState.failed => AppGlyphs.error,
      PowStepState.running => AppGlyphs.settings,
    };
    return Row(
      spacing: 12,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: step.state == PowStepState.running
              ? const Center(
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                )
              : GlyphIcon(icon, size: 14, color: color),
        ),
        Expanded(
          child: Text(
            step.text,
            textDirection: TextDirection.ltr,
            style: context.textTheme.bodySmall?.copyWith(
              color: step.state == PowStepState.failed ? color : null,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _logLine(String line) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Text(
      line,
      textDirection: TextDirection.ltr,
      style: context.textTheme.bodySmall?.copyWith(
        fontFamily: 'monospace',
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 2,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(powControllerProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final content = _contentList(context, controller);
        if (!widget.modal) {
          return CommonScaffold(
            title: context.appLocalizations.powTitle,
            actions: [
              controller.connected
                  ? IconButton(
                      tooltip: context.appLocalizations.powDisconnect,
                      onPressed: controller.busy
                          ? null
                          : () => unawaited(_disconnect()),
                      icon: const GlyphIcon(AppGlyphs.close, size: 20),
                    )
                  : const SizedBox.shrink(),
            ],
            body: content,
          );
        }
        return _modalShell(context, content);
      },
    );
  }

  Widget _contentList(BuildContext context, PowController controller) {
    final l = context.appLocalizations;
    final status = controller.status;
    final connected = controller.connected;
    final busy = controller.busy;
    final installProgress = controller.installProgress;
    final settings = controller.settings;
    final steps = status.steps;
    final logs = controller.logs;

    final content = ListView(
      shrinkWrap: widget.modal,
      padding: EdgeInsets.fromLTRB(
        22,
        widget.modal ? 4 : context.contentTopPadding,
        22,
        24 + BottomInsetScope.of(context),
      ),
      children: [
        if (installProgress != null) ...[
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: LinearProgressIndicator(value: installProgress),
              ),
              Text(
                '${(installProgress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                style: context.textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        ...generateSection(
          title: l.powTitle,
          isFirst: widget.modal,
          items: [
            _panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  Text(
                    l.powIntro,
                    style: context.textTheme.bodySmall,
                  ),
                  Builder(
                    builder: (context) {
                      final region = connected
                          ? (controller.exitRegion.isNotEmpty
                                ? controller.exitRegion
                                : settings.exitCountryCode)
                          : settings.exitCountryCode;
                      if (region.isEmpty) return const SizedBox.shrink();
                      final location = pow_models.regionName(region);
                      if (location.isEmpty) return const SizedBox.shrink();
                      return Row(
                        spacing: 8,
                        children: [
                          SizedBox(
                            width: 18,
                            child: CountryFlagEmoji(
                              region.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.2,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              location,
                              textDirection: TextDirection.ltr,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: connected
                                    ? context.colorScheme.primary
                                    : context.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (connected)
                    Row(
                      spacing: 10,
                      children: [
                        GlyphIcon(
                          AppGlyphs.shieldCheck,
                          size: 16,
                          color: context.colorScheme.primary,
                        ),
                        Expanded(
                          child: Text(
                            [
                              '127.0.0.1:${controller.exitPort}',
                              if (status.outerLabel.isNotEmpty)
                                status.outerLabel,
                            ].join(' · '),
                            textDirection: TextDirection.ltr,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colorScheme.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (controller.recovering)
                    Row(
                      spacing: 10,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: Center(
                            child: SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            l.powRescanStarted,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colorScheme.primary,
                            ),
                            textDirection: TextDirection.ltr,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 3,
                          ),
                        ),
                      ],
                    )
                  else if (controller.failure?.isNotEmpty == true)
                    Text(
                      controller.failure!,
                      textDirection: TextDirection.ltr,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.error,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  if (!controller.isWindows)
                    Text(
                      l.powWindowsOnly,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.error,
                      ),
                    ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: connected
                          ? context.colorScheme.primaryContainer
                          : null,
                      foregroundColor: connected
                          ? context.colorScheme.onPrimaryContainer
                          : null,
                    ),
                    onPressed: busy || !controller.isWindows
                        ? null
                        : connected
                        ? () => unawaited(_disconnect())
                        : () => unawaited(_connect()),
                    child: Text(
                      connected ? l.powDisconnect : l.powConnect,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ...generateSection(
          title: l.powStatus,
          items: [
            if (steps.isEmpty)
              Text(
                l.powStatusIdle,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              )
            else
              _panel(
                Column(
                  spacing: 8,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final step in steps) _stepRow(step),
                  ],
                ),
              ),
          ],
        ),
        ...generateSection(
          title: l.powSettings,
          items: [
            ListItem<String>.options(
              leading: const GlyphIcon(AppGlyphs.language),
              title: Text(l.powRegion),
              dialogTitle: l.powRegion,
              options: ['', ...pow_models.powRegionNames.keys.toList()..sort()],
              value: settings.exitCountryCode,
              textBuilder: (code) =>
                  _regionLabel(l, settings, code),
              onChanged: (code) => unawaited(
                ref.read(powControllerProvider).setExitRegion(code ?? ''),
              ),
            ),
            ListItem<String>.options(
              leading: const GlyphIcon(AppGlyphs.vpn),
              title: Text(l.powOuterTransport),
              dialogTitle: l.powOuterTransport,
              options: const [
                pow_models.outerAuto,
                'masque',
                'gool',
                'wireguard',
              ],
              value: settings.outerTransport,
              textBuilder: (option) => option == pow_models.outerAuto
                  ? l.powAuto
                  : pow_models.outerLabel(option),
              onChanged: (option) => unawaited(
                ref
                    .read(powControllerProvider)
                    .updateSettings(
                      settings.copyWith(outerTransport: option),
                    ),
              ),
            ),
            ListItem<String>.options(
              leading: const GlyphIcon(AppGlyphs.split),
              title: Text(l.powRecipe),
              dialogTitle: l.powRecipe,
              options: pow_models.recipes.toList(),
              value: settings.linkRecipe,
              textBuilder: (option) => option == pow_models.recipeAuto
                  ? l.powAuto
                  : option,
              onChanged: (option) => unawaited(
                ref
                    .read(powControllerProvider)
                    .updateSettings(settings.copyWith(linkRecipe: option)),
              ),
            ),
            ListItem<String>.options(
              leading: const GlyphIcon(AppGlyphs.rules),
              title: Text(l.powFirewall),
              dialogTitle: l.powFirewall,
              options: pow_models.firewalls.toList(),
              value: settings.firewallProfile,
              textBuilder: (option) => switch (option) {
                pow_models.firewallAuto => l.powFirewallAuto,
                pow_models.firewallIrancell => l.powFirewallIrancell,
                pow_models.firewallMci => l.powFirewallMci,
                _ => option,
              },
              onChanged: (option) => unawaited(
                ref
                    .read(powControllerProvider)
                    .updateSettings(
                      settings.copyWith(firewallProfile: option),
                    ),
              ),
            ),
            ListItem<String>.options(
              leading: const GlyphIcon(AppGlyphs.wrench),
              title: Text(l.powScanMode),
              dialogTitle: l.powScanMode,
              options: pow_models.scanModes.toList(),
              value: settings.scanMode,
              textBuilder: (option) => switch (option) {
                pow_models.scanTurbo => l.powScanTurbo,
                pow_models.scanBalanced => l.powScanBalanced,
                pow_models.scanThorough => l.powScanThorough,
                _ => option,
              },
              onChanged: (option) => unawaited(
                ref
                    .read(powControllerProvider)
                    .updateSettings(settings.copyWith(scanMode: option)),
              ),
            ),
            ListItem<String>.options(
              leading: const GlyphIcon(AppGlyphs.link),
              title: Text(l.powKeyFetch),
              dialogTitle: l.powKeyFetch,
              options: pow_models.keyFetches.toList(),
              value: settings.keyFetch,
              textBuilder: (option) => switch (option) {
                pow_models.keyAuto => l.powKeyAuto,
                pow_models.keyEch => l.powKeyEch,
                pow_models.keyFragment => l.powKeyFragment,
                pow_models.keyExternal => l.powKeyExternal,
                _ => option,
              },
              onChanged: (option) => unawaited(
                ref
                    .read(powControllerProvider)
                    .updateSettings(settings.copyWith(keyFetch: option)),
              ),
            ),
            ListItem<String>.options(
              leading: const GlyphIcon(AppGlyphs.settings),
              title: Text(l.powObfuscation),
              dialogTitle: l.powObfuscation,
              options: pow_models.obfuscationProfiles.toList(),
              value: settings.obfuscationProfile,
              textBuilder: (option) => option,
              onChanged: (option) => unawaited(
                ref
                    .read(powControllerProvider)
                    .updateSettings(
                      settings.copyWith(obfuscationProfile: option),
                    ),
              ),
            ),
            ListItem.toggle(
              leading: const GlyphIcon(AppGlyphs.vpn),
              title: Text(l.powChainPsiphon),
              subtitle: Text(
                l.powChainPsiphonDesc,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              value: settings.chainPsiphon,
              onChanged: (value) => unawaited(
                ref
                    .read(powControllerProvider)
                    .updateSettings(settings.copyWith(chainPsiphon: value)),
              ),
            ),
            ListItem.toggle(
              leading: const GlyphIcon(AppGlyphs.split),
              title: Text(l.powH2Fragment),
              value: settings.h2Fragmentation,
              onChanged: (value) => unawaited(
                ref
                    .read(powControllerProvider)
                    .updateSettings(
                      settings.copyWith(h2Fragmentation: value),
                    ),
              ),
            ),
            ListItem.toggle(
              leading: const GlyphIcon(AppGlyphs.rules),
              title: Text(l.powOptimized),
              value: settings.optimizedMode,
              onChanged: (value) => unawaited(
                ref
                    .read(powControllerProvider)
                    .updateSettings(
                      settings.copyWith(optimizedMode: value),
                    ),
              ),
            ),
            ListItem.toggle(
              leading: const GlyphIcon(AppGlyphs.star),
              title: Text(l.powIrancellH3),
              value: settings.irancellH3,
              onChanged: (value) => unawaited(
                ref
                    .read(powControllerProvider)
                    .updateSettings(
                      settings.copyWith(irancellH3: value),
                    ),
              ),
            ),
            ListItem.toggle(
              leading: const GlyphIcon(AppGlyphs.account),
              title: Text(l.powDirectFirst),
              value: settings.directPsiphonFirst,
              onChanged: (value) => unawaited(
                ref
                    .read(powControllerProvider)
                    .updateSettings(
                      settings.copyWith(directPsiphonFirst: value),
                    ),
              ),
            ),
          ],
        ),
        ...generateSection(
          title: l.powLogs,
          items: [
            ListItem(
              leading: const GlyphIcon(AppGlyphs.info),
              title: Text(_showLogs ? l.powHideLogs : l.powShowLogs),
              onTap: () => setState(() {
                _showLogs = !_showLogs;
              }),
            ),
            if (_showLogs)
              _panel(
                SizedBox(
                  height: 220,
                  child: logs.isEmpty
                      ? Center(
                          child: Text(
                            l.powStatusIdle,
                            style: context.textTheme.bodySmall,
                          ),
                        )
                      : ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            for (final line in logs) _logLine(line),
                          ],
                        ),
                ),
              ),
            ListItem(
              leading: const GlyphIcon(AppGlyphs.delete),
              title: Text(l.powForgetNetworks),
              subtitle: Text(
                l.powForgetNetworksDesc,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              onTap: busy
                  ? null
                  : () => unawaited(_forgetNetworks()),
            ),
            ListItem(
              leading: const GlyphIcon(AppGlyphs.block),
              title: Text(
                l.powRemove,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.error,
                ),
              ),
              subtitle: Text(
                l.powRemoveDesc,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              onTap: busy ? null : () => unawaited(_removeVyraxFree()),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
    return content;
  }

  Widget _modalShell(BuildContext context, Widget content) {
    final l = context.appLocalizations;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(22, 14, 12, 8),
          child: Row(
            children: [
              GlyphIcon(
                AppGlyphs.sparkle,
                size: 19,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(l.powTitle, style: context.textTheme.titleSmall),
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
    );
  }
}
