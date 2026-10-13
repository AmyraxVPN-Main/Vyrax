# Vyrax for macOS

Copyright (c) 2026 Amyrax. The application is free and MIT licensed.

## Install

Choose `macos-arm64` for an Apple Silicon Mac (M1 and later), or `macos-x64`
for an Intel Mac. macOS 13 Ventura or later is required. Open the DMG and drag
Vyrax to Applications. The ZIP contains the same standalone application.

These initial builds are ad-hoc signed, **not Apple Developer ID signed or
notarized**. macOS can block their first launch. After opening the downloaded
application, allow it in System Settings > Privacy & Security > Open Anyway.
Only proceed for a package you obtained from the official repository and
checked against its SHA256SUMS. No installer disables Gatekeeper globally.

## Network permissions

Vyrax runs as your regular user. Connecting in TUN or System Proxy mode opens
the native macOS administrator dialog for a narrow network helper. Delay tests,
import, settings and the interface need no administrator access. TUN uses a
native `utun` interface, IPv4/IPv6 and DNS through the selected proxy. Xray's
upstream sockets bypass that tunnel to prevent a loop. System Proxy mode sets
HTTP, HTTPS and SOCKS proxies on enabled network services.

On disconnect or a normal exit, the helper stops the tunnel and restores the
previous DNS/proxy configuration. A parent identity and heartbeat lease also
clean up after the main app crashes. An independent native process lease stops
sing-box if the privileged helper crashes. A root-owned rollback journal is recovered
at the next authorized connection after a helper/system crash. If another app
changes those preferences in the meantime, its changes are preserved.

Do not run two system VPNs concurrently. macOS VPN profiles managed by an
organization may restrict DNS/proxy changes. IPv4/IPv6 private LAN destinations
are bypassed; the shared split/bypass lists are applied inside Xray. A configured
domain bypass can still use the VPN DNS resolver; it is not per-app exclusion.

The window's top bar supports dragging; the close button hides to the menu bar.
Quit from the menu bar to stop Vyrax. Subscriptions, URL delay tests, Fastest and
Balance groups, Persian/English layouts, clipboard/QR, statistics and the
dismissible GitHub update banner share the existing desktop implementation.
Credentials are encrypted using Electron safeStorage and the macOS Keychain;
Vyrax refuses to silently replace that with plaintext encryption storage.

## Build

On a native macOS ARM64 or Intel machine, install Node.js 22.12+ and Python 3.12+
and the Xcode command-line tools, then run:

```sh
bash scripts/build-macos.sh arm64   # Apple Silicon
# or: bash scripts/build-macos.sh x64
```

The script verifies pinned upstream runtimes, builds the shared UI, compiles
the native permission/process/network helpers, signs each nested component,
verifies the bundle and writes DMG/ZIP artifacts under `release/macos-VERSION`.
No Python or Node installation is required on users' Macs. The source pins are
in `vendor/macos-versions.json`; exact core sources accompany the artifacts.
See `macos-sources.md` before replacing a core and re-signing.

`VYRAX_MAC_SIGN_IDENTITY` can select an installed Developer ID identity instead
of ad-hoc signing. Notarization and stapling are a separate publisher step:
submit the signed ZIP with `xcrun notarytool submit --wait`, then staple the
approved app/DMG. Setting an identity alone does not notarize the application.
Keep certificates and Apple account secrets out of the repository.

The standalone desktop helper uses the deprecated but currently available
Authorization Services execution API; it is not an App Store/Network Extension
build. Moving to a persistent SMAppService daemon requires a separate signed
service design. iOS requires a distinct Network Extension and is not provided
by this macOS bundle.

## Validation limits

The macOS Actions workflow builds each architecture on a native macOS 15
runner. Synthetic local Xray configurations test delay, System Proxy/TUN
connections to public HTTPS endpoints, subscription downloads, live selection,
network restoration and process leases. A sandboxed Electron UI test covers
English/Persian, encrypted persistence, clipboard/QR and dialog responsiveness.
No real subscription or credentials are used. Reports accompany each build.

These runner tests do not establish behavior on every Mac, an organization-managed
network, an actual Gatekeeper download, or every server/transport. The native
authorization dialog still needs a user-facing check on a physical Mac.

Project: https://github.com/AmyraxVPN-Main/Vyrax

Telegram: https://t.me/AmyraxVPN
