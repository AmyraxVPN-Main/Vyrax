# Vyrax

Free and open-source VPN client by **Amyrax**.

**Copyright (c) 2026 Amyrax.** Vyrax application code is licensed under the
[MIT license](LICENSE). Keep the copyright and license notice when distributing
copies or substantial portions. Third-party components keep their own licenses;
see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

- Project: https://github.com/AmyraxVPN-Main/Vyrax
- Telegram: https://t.me/AmyraxVPN
- Latest published release: https://github.com/AmyraxVPN-Main/Vyrax/releases/latest

## Current platform

Windows x64 uses a React interface in a native C# / WebView2 host. Xray runs the
proxy transports; sing-box and Wintun provide TUN support. VLESS, VMess, Trojan
and Shadowsocks configs can be imported as individual or grouped subscriptions.
Automatic and balanced routing stay inside the selected group.

Android uses a separate Java/WebView host with Android VPN services. Builds cover
`arm64-v8a`, `armeabi-v7a` and a universal APK; see [Android build details](docs/android.md)
for requirements, behavior and testing limits.

Linux desktop packages are available as `.deb` and portable `.tar.gz` for x64 and
ARM64. The Electron host shares the same interface and uses Xray plus a
Polkit-authorized sing-box TUN helper. See [Linux installation/build details](docs/linux.md).
macOS ARM64 (Apple Silicon) and x64 (Intel) use the same desktop interface with
native authorization, Keychain storage and a leased `utun` helper. Build outputs
are DMG/ZIP packages; see [macOS installation/build details](docs/macos.md),
including the initial ad-hoc signing and notarization limitation.
iOS is planned.
See [the platform plan](docs/platforms.md) for their required VPN services.

## Windows build

Prerequisites: Windows x64, Node.js 20.19+ or 22.12+, .NET Framework 4.x C# compiler,
Microsoft Edge WebView2 Runtime and NSIS 3 for the installer.

```powershell
npm ci
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/prepare-vendor.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-windows.ps1
& 'C:\Program Files (x86)\NSIS\makensis.exe' /V2 scripts\installer.nsi
```

The vendor preparation script downloads the pinned archives, checks SHA-256,
extracts the required runtime and license files, prepares npm notices and
generates offline country data. Downloads and binaries are excluded from Git.
Build outputs are in `release`; building does not install or start the app.
The application asks for administrator access for TUN on Windows.

## Updates

The app quietly checks the repository's public GitHub `releases/latest` endpoint
after startup and every 12 hours while visible. Only a published stable release
with a higher semantic version shows the compact dismissible banner. Failed
requests, an empty releases page, drafts and prereleases do not show a banner.
Dismissal is saved for that version; a later version can show a new banner.
Clicking the banner opens GitHub's latest release page in the default browser.
No updater silently downloads, executes or installs anything.

Publish tags as `vMAJOR.MINOR.PATCH` (for example `v0.1.18`), attach the platform
installer and corresponding source/required third-party notices, then publish
the release as stable. A source commit or draft alone does not trigger updates.
The repository and channel are configured in `project.json` and shared by the UI
and native host. Automatic checks send no config, subscription or account data.

## Checks

```powershell
node .tools/selftest/subscriptions.mjs
node .tools/selftest/releases.mjs
powershell -NoProfile -ExecutionPolicy Bypass -File .tools/selftest/run-updates.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .tools/selftest/run-pool.ps1
node .tools/selftest/verify-release.mjs
```

Do not commit VPN credentials, subscriptions, user stores, tunnel logs or local
diagnostic captures. The installed app's encrypted store is outside this source
tree and is not part of the repository.

### iPhone / iPad development build

The iOS host and native Packet Tunnel extension are in `ios`. See [iOS build and signing guide](docs/ios.md). Unsigned device archives and the simulator app are development outputs; a publicly installable iPhone VPN still requires Apple signing/provisioning and real-device testing.
