import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'engine.dart';
import 'models.dart';
import 'provider.dart';

Future<void> showSpoofDialog(BuildContext context) => showDialog<void>(
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
      child: const KeyboardInsetHold(child: SpoofView(modal: true)),
    ),
  ),
);

class SpoofView extends ConsumerStatefulWidget {
  const SpoofView({super.key, this.modal = false});

  final bool modal;

  @override
  ConsumerState<SpoofView> createState() => _SpoofViewState();
}

class _SpoofViewState extends ConsumerState<SpoofView> {
  final _links = TextEditingController();
  SpoofImportResult? _lastImport;
  bool _busyImport = false;

  static const _fragmentOptions = [
    'plain',
    'full5',
    'full10',
    'full20',
    'multi64',
    'gfw_first',
  ];

  @override
  void dispose() {
    _links.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    if (_busyImport) return;
    setState(() {
      _busyImport = true;
      _lastImport = null;
    });
    final result = await ref.read(spoofControllerProvider).importText(
      _links.text,
    );
    if (result.ok) {
      _links.clear();
    }
    if (mounted) {
      setState(() {
        _busyImport = false;
        _lastImport = result;
      });
    }
  }

  Future<void> _connect(String id) => ref
      .read(spoofControllerProvider)
      .connect(id);

  Future<void> _disconnect() => ref.read(spoofControllerProvider).disconnect();

  Future<void> _remove(String id, String current) async {
    final controller = ref.read(spoofControllerProvider);
    if (id != current) {
      await controller.remove(id);
      return;
    }
    await dialogs.showCommonDialog<bool>(
      context: context,
      child: CommonDialog(
        title: context.appLocalizations.delete,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.appLocalizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.appLocalizations.delete),
          ),
        ],
        child: Text(context.appLocalizations.spoofRemoveConfirm),
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        await controller.remove(id);
      }
    });
  }

  Widget _panel(Widget child, {bool selected = false}) => Container(
    padding: const EdgeInsets.all(16),
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

  String _fragmentLabel(AppLocalizations l, SpoofFragmentSettings settings) {
    if (!settings.hasFragment) return l.spoofFragmentPlain;
    return settings.length;
  }

  String _fragmentOptionLabel(AppLocalizations l, String option) {
    if (option == 'plain') {
      return l.spoofFragmentPlain;
    }
    return _fragmentLabel(
      l,
      SpoofFragmentSettings.forStrategy(
        SpoofFragmentStrategyName.fromName(option),
      ),
    );
  }

  String _carrierLabel(AppLocalizations l, SpoofCarrier carrier) =>
      switch (carrier) {
        SpoofCarrier.auto => l.spoofCarrierAuto,
        SpoofCarrier.mci => l.spoofCarrierMci,
        SpoofCarrier.irancell => l.spoofCarrierIrancell,
      };

  Widget _statusIcon(SpoofEngineState state) {
    final color = state.running
        ? context.colorScheme.primary
        : state.failure != null
        ? context.colorScheme.error
        : context.colorScheme.outlineVariant;
    return GlyphIcon(
      state.failure != null ? AppGlyphs.error : AppGlyphs.shieldCheck,
      size: 18,
      color: color,
    );
  }

  String _statusLabel(AppLocalizations l, SpoofEngineState state) {
    if (state.running) return l.spoofRunning;
    if (state.failure != null) return l.spoofFailed;
    return l.spoofIdle;
  }

  Widget _bundleCard(
    AppLocalizations l,
    SpoofController controller,
    SpoofBundle bundle,
  ) {
    final active = bundle.id == controller.activeId;
    final connected = active && controller.engineState.running;
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  bundle.label,
                  style: context.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              CommonMinIconButtonTheme(
                child: IconButton(
                  tooltip: l.delete,
                  onPressed: controller.busy
                      ? null
                      : () => unawaited(
                          _remove(bundle.id, controller.activeId ?? ''),
                        ),
                  icon: const GlyphIcon(AppGlyphs.delete, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${bundle.servers.length} ${l.spoofServers}',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: connected
                  ? context.colorScheme.primaryContainer
                  : null,
              foregroundColor: connected
                  ? context.colorScheme.onPrimaryContainer
                  : null,
            ),
            onPressed: controller.busy
                ? null
                : connected
                ? () => unawaited(_disconnect())
                : () => unawaited(_connect(bundle.id)),
            child: Text(connected ? l.spoofDisconnect : l.spoofConnect),
          ),
        ],
      ),
      selected: active,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(spoofControllerProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) => _buildContent(context, controller),
    );
  }

  Widget _buildContent(BuildContext context, SpoofController controller) {
    final l = context.appLocalizations;
    final state = controller.engineState;
    final installProgress = controller.installProgress;
    final connected = controller.activeId != null && state.running;

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
          title: l.spoofImport,
          isFirst: widget.modal,
          items: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.spoofIntro, style: context.textTheme.bodySmall),
                const SizedBox(height: 16),
                TextField(
                  controller: _links,
                  maxLines: 3,
                  enabled: !controller.busy,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: l.spoofImportHint,
                    border: AppShape.input,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_lastImport case final import?)
                      Expanded(
                        child: Text(
                          import.ok ? l.spoofImported : l.spoofImportFailed,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: import.ok
                                ? context.colorScheme.primary
                                : context.colorScheme.error,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      const Spacer(),
                    FilledButton.icon(
                      onPressed: controller.busy || _links.text.isEmpty
                          ? null
                          : () => unawaited(_import()),
                      icon: const GlyphIcon(AppGlyphs.importFile, size: 16),
                      label: Text(l.spoofImport),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        ...generateSection(
          title: l.spoofSettings,
          items: [
            ListItem<SpoofCarrier>.options(
              leading: const GlyphIcon(AppGlyphs.account),
              title: Text(l.spoofCarrier),
              dialogTitle: l.spoofCarrier,
              options: SpoofCarrier.values,
              value: controller.carrier,
              textBuilder: (carrier) => _carrierLabel(l, carrier),
              onChanged: (carrier) => unawaited(
                ref
                    .read(spoofControllerProvider)
                    .updateSettings(newCarrier: carrier),
              ),
            ),
            ListItem<String>.options(
              leading: const GlyphIcon(AppGlyphs.split),
              title: Text(l.spoofFragment),
              dialogTitle: l.spoofFragment,
              options: _fragmentOptions,
              value: controller.fragment,
              textBuilder: (option) => _fragmentOptionLabel(l, option),
              onChanged: (fragment) => unawaited(
                ref
                    .read(spoofControllerProvider)
                    .updateSettings(newFragment: fragment),
              ),
            ),
            ListItem.toggle(
              leading: const GlyphIcon(AppGlyphs.rules),
              title: Text(l.spoofIranDirect),
              value: controller.iranDirect,
              onChanged: (value) => unawaited(
                ref
                    .read(spoofControllerProvider)
                    .updateSettings(newIranDirect: value),
              ),
            ),
          ],
        ),
        ...generateSection(
          title: l.spoofLinks,
          items: [
            if (controller.bundles.isEmpty)
              _panel(
                Column(
                  spacing: 8,
                  children: [
                    GlyphIcon(
                      AppGlyphs.link,
                      size: 20,
                      color: context.colorScheme.outlineVariant,
                    ),
                    Text(
                      l.spoofEmpty,
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodySmall,
                    ),
                  ],
                ),
              )
            else ...[
              for (final bundle in controller.bundles)
                _bundleCard(l, controller, bundle),
            ],
          ],
        ),
        ...generateSection(
          title: l.spoofStatus,
          items: [
            ListItem(
              leading: _statusIcon(state),
              title: Text(_statusLabel(l, state)),
              subtitle: state.running
                  ? Text(
                      [
                        if (state.probeMs > 0) '${state.probeMs} ms',
                        if (state.exitCountry?.isNotEmpty == true)
                          '${l.spoofExit}: ${state.exitCountry}',
                      ].join(' · '),
                      textDirection: TextDirection.ltr,
                    )
                  : state.failure != null
                  ? Text(
                      state.failure!,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: context.colorScheme.error,
                      ),
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );

    if (!widget.modal) {
      return CommonScaffold(
        title: l.spoofTitle,
        actions: [
          connected
              ? IconButton(
                  tooltip: l.spoofDisconnect,
                  onPressed: controller.busy ? null : () => unawaited(_disconnect()),
                  icon: const GlyphIcon(AppGlyphs.close, size: 20),
                )
              : const SizedBox.shrink(),
        ],
        body: content,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(22, 14, 12, 8),
          child: Row(
            children: [
              GlyphIcon(
                AppGlyphs.vpn,
                size: 19,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(l.spoofTitle, style: context.textTheme.titleSmall),
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
