# Vyrax 0.1.17

About now opens a dedicated, bilingual dialog with the Vyrax version,
Copyright (c) 2026 Amyrax, the MIT application license, Telegram channel
https://t.me/AmyraxVPN, the project repository and bundled component credits.
Project destinations are configured in `project.json`, shared by the UI and
embedded in the Windows host. Native external-link actions accept only the
channel, source repository and latest release page, never an arbitrary URL or
executable.

The app quietly checks GitHub's latest stable release after startup and every
12 hours while visible. Only a published stable release with a higher semantic
version shows a compact banner using the current theme. The banner opens
https://github.com/AmyraxVPN-Main/Vyrax/releases/latest and can be dismissed.
Dismissal is stored by repository and version across app restarts; later versions
can notify again. About offers a manual check and a release link even after the
banner has been hidden. Network errors and rate limits are quiet during automatic
checks and reported only in the manually requested About status.

The native client uses the active system proxy, TLS verification, a 12-second
deadline and a 256 KiB response limit. Checks send no VPN configs, subscription
links, credentials or app account data. Drafts, prereleases, unpublished/future
records, equal/older versions and invalid repository/tag URLs do not notify.
Update installation is not automatic; downloading and installing remains on the
GitHub release page. The home layout becomes compact while a banner is visible
so the connection control, readouts, server selection and navigation stay visible.

The application is MIT licensed under Amyrax's copyright. Third-party copyrights
and licenses are retained, with the complete GPL text and dependency notices in
binary packages. Source/build preparation now includes a README, a verified
pinned-vendor download script, dependency notices, source packaging and exclusions
for local data, binaries, logs and diagnostic captures. Windows is the only built
platform; Android, iOS, macOS and Linux requirements are documented in
`docs/platforms.md` without claiming those platforms already work.

## Validation

- 44 semantic version, published-release, destination and dismissal checks passed.
- 21 native transport/link checks passed for success, empty releases, rate limits,
  server errors, redirects, malformed/oversized responses, cancellation and fixed
  external destinations. The client does not forward release bodies or author data.
- Existing subscription/grouping and config-sharing tests passed.
- Pinned sing-box, Xray, WebView2 and Wintun archives downloaded, matched their
  SHA-256 records and prepared successfully. Notices were collected for 101
  installed dependencies; offline country data generation passed.
- Isolated native UI QA checked Persian/English About, channel/release buttons,
  light/dark banners, idle/connected home layout, dismissal, a restart without
  repeating the dismissed version, and a later-version notice after manual check.
  The preview uses synthetic metadata, an in-memory store, mock VPN services and
  recorded link targets. Its mock release data is not included in production.
- The production update client queried the real configured GitHub repository:
  no release was published, so it returned no update. No test release was created
  on GitHub to make a banner appear.
- Production UI, native host and helper build successfully; executable/installer
  icon resources, administrator levels, Amyrax copyright resources and installed
  license files are checked by `verify-release.mjs`.

The public repository was created at https://github.com/AmyraxVPN-Main/Vyrax.
No GitHub release or installer publication is part of this update. The installed
app, current VPN and saved user data were not changed. Local package hashes are
recorded in `release/verification-0.1.17.json`.
