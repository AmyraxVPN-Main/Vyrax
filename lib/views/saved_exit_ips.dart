import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/providers/saved_exit_ips.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class SavedExitIpsView extends ConsumerWidget {
  const SavedExitIpsView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final data = ref.watch(savedExitIpsProvider);
    return CommonScaffold(
      title: l.savedExitIps,
      body: data.when(
        loading: () =>
            const NullStatus(illustration: NullStatusIllustration.data),
        error: (_, _) => Center(child: Text(l.savedExitIpsError)),
        data: (ips) => ListView(
          padding: EdgeInsets.only(top: context.contentTopPadding, bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.savedExitIpsHint),
            ),
            for (final entry in ips.entries)
              ContextMenuRegion(
                menuItems: [
                  CommonPopupMenuItem(
                    glyph: AppGlyphs.delete,
                    label: l.delete,
                    onPressed: () => globalState.safeRun(
                      () => ref
                          .read(savedExitIpsProvider.notifier)
                          .toggle(entry.key, entry.value),
                    ),
                  ),
                ],
                child: ListItem(
                  leading: const GlyphIcon(AppGlyphs.star),
                  title: Text(entry.key),
                  subtitle: Text(entry.value),
                  onTap: () => globalState.safeRun(
                    () => Clipboard.setData(ClipboardData(text: entry.key)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
