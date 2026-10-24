import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class _DnsPreset {
  const _DnsPreset(this.label, this.servers);
  final String label;
  final List<String> servers;
}

const _dnsPresets = [
  _DnsPreset('Cloudflare', ['1.1.1.1', '1.0.0.1']),
  _DnsPreset('Google', ['8.8.8.8', '8.8.4.4']),
  _DnsPreset('AdGuard', ['94.140.14.14', '94.140.15.15']),
  _DnsPreset('Shecan', ['178.22.122.100', '185.51.200.2']),
  _DnsPreset('Begzar', ['185.55.226.26', '185.55.225.25']),
  _DnsPreset('Electro', ['78.157.42.100', '78.157.42.101']),
  _DnsPreset('403.online', ['10.202.10.202', '10.202.10.102']),
  _DnsPreset('Radar Game', ['10.202.10.10', '10.202.10.11']),
];

class DnsPresetsCard extends ConsumerWidget {
  const DnsPresetsCard({super.key});

  void _apply(WidgetRef ref, _DnsPreset preset) {
    ref.read(patchClashConfigProvider.notifier).update((state) {
      final keys = {...state.dnsOverrideKeys}
        ..add(DnsOverrideKey.nameserver)
        ..add(DnsOverrideKey.defaultNameserver);
      return state.copyWith(
        dnsOverrideKeys: keys,
        dns: state.dns.copyWith(
          nameserver: [...preset.servers],
          defaultNameserver: [...preset.servers],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
      patchClashConfigProvider.select(
        (state) => state.dnsOverrideKeys.contains(DnsOverrideKey.nameserver)
            ? state.dns.nameserver
            : <String>[],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
          child: Text(
            context.appLocalizations.dnsPresets,
            style: context.textTheme.titleSmall,
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _dnsPresets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final preset = _dnsPresets[index];
              final selected =
                  active.length == preset.servers.length &&
                  active.every(preset.servers.contains);
              return ActionChip(
                visualDensity: VisualDensity.compact,
                avatar: selected
                    ? const Icon(Icons.check, size: 16)
                    : const GlyphIcon(AppGlyphs.dns, size: 16),
                label: Text(preset.label),
                onPressed: () => _apply(ref, preset),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Quick optimization presets: each one writes a small, documented set of
/// core settings — nothing is hidden or faked.
enum OptimizationPreset { standard, gaming, lite }

class _OptimizationPresetSpec {
  const _OptimizationPresetSpec({
    required this.unifiedDelay,
    required this.tcpConcurrent,
    this.geodataLoader,
    this.dnsServers,
  });
  final bool unifiedDelay;
  final bool tcpConcurrent;
  final GeodataLoader? geodataLoader;
  final List<String>? dnsServers;
}

final _optimizationPresets = {
  OptimizationPreset.standard: const _OptimizationPresetSpec(
    unifiedDelay: true,
    tcpConcurrent: true,
  ),
  OptimizationPreset.gaming: const _OptimizationPresetSpec(
    unifiedDelay: true,
    tcpConcurrent: true,
    dnsServers: ['10.202.10.10', '10.202.10.11'],
  ),
  OptimizationPreset.lite: const _OptimizationPresetSpec(
    unifiedDelay: true,
    tcpConcurrent: true,
    geodataLoader: GeodataLoader.memconservative,
    dnsServers: ['94.140.14.14', '94.140.15.15'],
  ),
};

bool _sameServers(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

OptimizationPreset currentOptimizationPreset(PatchClashConfig config) {
  for (final entry in _optimizationPresets.entries) {
    final spec = entry.value;
    if (spec.unifiedDelay != config.unifiedDelay) continue;
    if (spec.tcpConcurrent != config.tcpConcurrent) continue;
    if (spec.geodataLoader != null &&
        spec.geodataLoader != config.geodataLoader) {
      continue;
    }
    final servers = spec.dnsServers;
    if (servers != null &&
        (!config.dnsOverrideKeys.contains(DnsOverrideKey.nameserver) ||
            !_sameServers(config.dns.nameserver, servers))) {
      continue;
    }
    return entry.key;
  }
  return OptimizationPreset.standard;
}

class OptimizationCard extends ConsumerWidget {
  const OptimizationCard({super.key});

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final appLocalizations = context.appLocalizations;
    final config = ref.read(patchClashConfigProvider);
    final selected = await showDialog<OptimizationPreset>(
      context: context,
      builder: (dialogContext) => CommonDialog(
        title: appLocalizations.optimization,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final preset in OptimizationPreset.values)
              ListTile(
                title: Text(switch (preset) {
                  OptimizationPreset.standard => appLocalizations.defaultText,
                  OptimizationPreset.gaming => appLocalizations.gamePreset,
                  OptimizationPreset.lite => appLocalizations.litePreset,
                }),
                subtitle: Text(switch (preset) {
                  OptimizationPreset.standard =>
                    appLocalizations.standardPresetDesc,
                  OptimizationPreset.gaming => appLocalizations.gamePresetDesc,
                  OptimizationPreset.lite => appLocalizations.litePresetDesc,
                }),
                trailing: currentOptimizationPreset(config) == preset
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(dialogContext).pop(preset),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    final spec = _optimizationPresets[selected]!;
    ref.read(patchClashConfigProvider.notifier).update((state) {
      var dns = state.dns;
      var keys = state.dnsOverrideKeys;
      if (spec.dnsServers != null) {
        keys = {...keys}
          ..add(DnsOverrideKey.nameserver)
          ..add(DnsOverrideKey.defaultNameserver);
        dns = dns.copyWith(
          nameserver: [...spec.dnsServers!],
          defaultNameserver: [...spec.dnsServers!],
        );
      }
      return state.copyWith(
        unifiedDelay: spec.unifiedDelay,
        tcpConcurrent: spec.tcpConcurrent,
        geodataLoader: spec.geodataLoader ?? state.geodataLoader,
        dns: dns,
        dnsOverrideKeys: keys,
      );
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final preset = ref.watch(
      patchClashConfigProvider.select(currentOptimizationPreset),
    );
    return ListItem(
      leading: const GlyphIcon(AppGlyphs.bolt),
      title: Text(appLocalizations.optimization),
      subtitle: Text(appLocalizations.optimizationDesc),
      trailing: Text(
        switch (preset) {
          OptimizationPreset.standard => appLocalizations.defaultText,
          OptimizationPreset.gaming => appLocalizations.gamePreset,
          OptimizationPreset.lite => appLocalizations.litePreset,
        },
      ),
      onTap: () => _pick(context, ref),
    );
  }
}
