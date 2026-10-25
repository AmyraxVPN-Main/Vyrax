import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'monitor.dart';

final releaseMonitorProvider = Provider<ReleaseMonitor>((ref) {
  final monitor = ReleaseMonitor(
    fetch: request.checkForUpdate,
    readDismissed: () async =>
        (await preferences.sharedPreferencesCompleter.future)?.getString(
          'dismissed-release:$repository',
        ),
    writeDismissed: (tag) async {
      final store = await preferences.sharedPreferencesCompleter.future;
      if (store == null ||
          !await store.setString('dismissed-release:$repository', tag)) {
        throw StateError('Could not save update preference');
      }
    },
  );
  ref.listen(
    appSettingProvider.select((s) => s.autoCheckUpdate),
    (_, value) => monitor.setEnabled(value),
    fireImmediately: true,
  );
  ref.listen(
    appVisibleProvider,
    (_, value) => monitor.setVisible(value),
    fireImmediately: true,
  );
  ref.onDispose(monitor.dispose);
  // Before the app is attached there is no window to notify, and a failed
  // early probe would leave a retry timer behind; attach() starts the first
  // check once the session is live.
  if (globalState.isAttach == true) {
    monitor.start();
  }
  return monitor;
});

class ReleaseNotice extends ConsumerWidget {
  const ReleaseNotice({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitor = ref.watch(releaseMonitorProvider);
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final release = monitor.release;
        if (release == null) return const SizedBox.shrink();
        final l = context.appLocalizations;
        return Material(
          color: context.colorScheme.secondaryContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
              child: Row(
                children: [
                  const GlyphIcon(AppGlyphs.cloudDownload),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${l.discoverNewVersion} ${release['tag_name']}',
                    ),
                  ),
                  TextButton(
                    onPressed: () => unawaited(
                      launchUrl(
                        Uri.parse(
                          'https://github.com/$repository/releases/latest',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                    child: Text(l.goDownload),
                  ),
                  IconButton(
                    tooltip: l.hideUpdateNotice,
                    onPressed: () =>
                        unawaited(globalState.safeRun(monitor.dismiss)),
                    icon: const GlyphIcon(AppGlyphs.close),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
