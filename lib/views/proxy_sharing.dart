import 'dart:io';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class ProxySharingView extends ConsumerStatefulWidget {
  const ProxySharingView({super.key});
  @override
  ConsumerState<ProxySharingView> createState() => _ProxySharingViewState();
}

class _ProxySharingViewState extends ConsumerState<ProxySharingView> {
  late Future<List<NetworkInterface>> _interfaces = NetworkInterface.list(
    type: InternetAddressType.IPv4,
  );
  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final config = ref.watch(patchClashConfigProvider);
    final running = ref.watch(isStartProvider);
    final authenticated = ref.watch(
      networkSettingProvider.select((s) => s.authentication.enable),
    );
    return CommonScaffold(
      title: l.proxySharing,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.sync,
          tooltip: l.update,
          onPressed: () => setState(() {
            _interfaces = NetworkInterface.list(type: InternetAddressType.IPv4);
          }),
        ),
      ],
      body: ListView(
        padding: EdgeInsets.only(top: context.contentTopPadding, bottom: 24),
        children: [
          ConfigToggleItem(
            title: (l) => l.allowLan,
            subtitle: (l) => l.proxySharingHint,
            selector: patchClashConfigProvider.select((s) => s.allowLan),
            onChanged: (ref, value) => ref
                .read(patchClashConfigProvider.notifier)
                .update((s) => s.copyWith(allowLan: value)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l.proxySharingInstructions),
          ),
          if (!running || !config.allowLan)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.proxySharingConnect),
            ),
          if (authenticated)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.proxySharingAuthentication),
            ),
          FutureBuilder(
            future: _interfaces,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l.proxySharingNoAddresses),
                );
              }
              if (!snapshot.hasData) {
                return const NullStatus(
                  illustration: NullStatusIllustration.data,
                );
              }
              final hosts = {
                for (final interface in snapshot.data!)
                  for (final address in interface.addresses) address.address,
              };
              if (hosts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l.proxySharingNoAddresses),
                );
              }
              return Column(
                children: [
                  for (final host in hosts)
                    ListItem(
                      leading: const GlyphIcon(AppGlyphs.copy),
                      title: Text('$host:${config.mixedPort}'),
                      subtitle: Text(l.proxySharingEndpoint),
                      onTap: () => globalState.safeRun(
                        () => Clipboard.setData(
                          ClipboardData(text: '$host:${config.mixedPort}'),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
