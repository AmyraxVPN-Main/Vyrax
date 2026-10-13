# Android build

Vyrax Android uses the shared React interface in Android System WebView, a native
Java host, Android `VpnService`, Xray-core and hev-socks5-tunnel. Minimum Android
version is 10 (API 29), matching the bundled tunnel library. The APK supports English/Persian and the same themes,
config imports, subscriptions, QR sharing, routing lists, delay tests and About.

## Packages

- `arm64-v8a`: ARM 64-bit phones/tablets.
- `armeabi-v7a`: ARM 32-bit devices.
- `universal`: ARM 32/64-bit plus x86/x86_64, selected automatically at install.
- Separate x86/x86_64 builds are also generated for compatible devices/emulators.

All variants share the application ID `com.amyrax.vyrax` and versionCode 21.
They replace each other when signed by the same key; switching variants does
not create another app or remove its saved subscriptions.

## Requirements

JDK 17, Node.js 20.19+ or 22.12+, Android SDK platform 35 and build-tools 35.0.0.
Set `JAVA_HOME` and `ANDROID_HOME`; accept Android SDK licenses through Google's
SDK manager. The Gradle wrapper uses pinned Gradle 8.9 with a verified checksum.

```powershell
npm ci
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/prepare-android.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-android.ps1
```

Debug APKs are signed by the Android development key. For distributable APKs,
set `VYRAX_ANDROID_KEYSTORE`, `VYRAX_ANDROID_STORE_PASSWORD`,
`VYRAX_ANDROID_KEY_ALIAS`, `VYRAX_ANDROID_KEY_PASSWORD`, then run the build script
with `-Release`. Signing keys and passwords must stay outside the source tree.
Keep the same private signing key for future updates; a different signing key
cannot upgrade the installed app. APKs are written under `release/android-VERSION`.
When Google Maven is unavailable on a network, an explicit HTTPS mirror can be
selected with `VYRAX_GOOGLE_MAVEN_MIRROR`; normal builds use Google Maven.
Increase `versionCode` in `android/app/build.gradle` for every distributed update.

## Connection behavior

VPN mode asks Android for its VPN permission, then redirects IPv4/IPv6 device
traffic through the selected profile. The host is excluded from the VPN to
prevent recursive core connections; the host's subscription/update requests
use the active local proxy explicitly. DNS traffic routes through the proxy,
including when split routing is enabled. No root permission is required.

On a fresh installation, TUN is the initial UI and native connection mode.
An explicitly saved Proxy choice remains selected after updating.
Subscriptions first use the ordinary network (four-second budget while connected),
then the active local proxy if the panel is blocked/unreachable there. This covers
panels that reject VPN exit addresses without stopping the user's VPN. Downloads
handle gzip, bounded redirects and a four-MiB decompressed response limit.

Delay tests use the same HTTPS 204 URL as FlClash's default URL test, with two
HTTP/1.1 HEAD requests over a private SOCKS5 connection. The second successful response is
the warmed delay; a failed second attempt retains the first successful result.
The complete network probe has an eight-second budget. A received HTTP response,
including a redirect or error status, is measured like PC/Mihomo URLTest; it is
not a download/content check. Failed authentication, CONNECT, TLS or transport
connections display Timeout, never a made-up delay. SOCKS5 avoids counting an
intermediate HTTP proxy's synthetic error as a target response. Probe configurations omit
traffic counters and sniffing, with at most three simultaneous probes (two on
Android low-RAM devices), independently of the UI/network workers.

The Android interface uses CSS transforms for the dial, orbit, tab thumb, segments
and toggles. Large SVG gooey filters and per-frame geometry sampling are disabled
on Android. The opaque dial masks orbit items as they emerge/return. The connected
hero moves using a transform, lists skip offscreen painting on supported WebViews,
and UI timers/render events pause in the background while the VPN keeps running.

## Installation prompt

Release APKs are signed with the owner's persistent RSA key using APK v2/v3
signatures, and are neither debug nor test-only packages. The 0.1.21 signature
matches the prior releases; a signed 0.1.20 → 0.1.21 upgrade retains the encrypted store.
An Android/Play Protect prompt about an unknown app or installation source is an
external trust decision; valid signing cannot guarantee its removal. Do not disable
Play Protect or rotate the signing key to work around it. Store publication and
Google's review/reputation process are separate from building a signed APK.

Proxy mode provides local SOCKS/HTTP listeners. Android does not let ordinary
apps enable a device-wide system proxy; apps must opt into the local endpoint.
Use VPN mode to cover all device traffic. Optional proxy sharing exposes an HTTP
listener to the local network only when the user enables it.

The foreground notification offers disconnect and keeps the service alive when
the UI moves to the background. VPN revoke stops the connection. Auto-connect
works when opening the app; auto-reconnect restarts a failed core/tunnel when
enabled. This build does not enable connections during device boot.

Automatic selection uses Xray's observatory and leastPing/leastLoad balancing
within the active subscription. It changes routing for new connections without
restarting the core; existing connections retain their current outbound. Manual
selection removes the balancing configuration and reconnects to that profile.
The initial fallback is the chosen profile, rather than the first catalog item.
A failed initial automatic handshake retries within the original eight-second
budget so the first observatory results can supply a working route.

Android 0.1.21 pins the official AndroidLibXrayLite/Xray 26.3.27 release, matching
the Windows core. The previous 26.10.10 Android core rejects public plaintext
VLESS/Trojan configurations that the desktop core accepts; one such outbound
also prevented an entire automatic pool from starting. Imported profiles keep
their provider's transport/security settings. TLS/REALITY verification remains
enabled as configured. REALITY uses the same default fingerprint/key fields as
desktop. Traffic counters use the compatible per-outbound native statistics API.

## Storage, links and licenses

Profiles use AES-GCM encryption with an Android Keystore key; Android backup is
disabled. The WebView native bridge is limited to the bundled HTTPS asset origin
and the main frame. Unbundled WebView network loads/navigation are blocked. Native
project links accept only the configured channel, repository and release page.

Pinned Android AAR hashes and source/license references are in
`vendor/android-versions.json`. Full LGPL/GPL/MPL/MIT notices ship in the APK assets.
The app code is MIT, Copyright (c) 2026 Amyrax. For a public binary distribution,
include the corresponding library source and application build/relink instructions;
the AARs can be replaced by a modified interface-compatible library. No signing
key restriction prevents building and installing a modified copy under its own key.
See [library build/relink instructions](android-relinking.md).

## Validation

`scripts/build-android.ps1` runs native unit tests and builds the APK variants.
`NativeSmokeTest` additionally checks native-core startup, all routing modes,
Keystore storage, tunnel-library loading and an HTTP request through a synthetic
loopback test server in an isolated emulator. Actual phone VPN behavior, battery
management and OEM background restrictions require device testing.

The 0.1.18 build passed 8 JVM tests and emulator checks on Android 11 / WebView 83:
native libraries, all three selection modes, encrypted storage, authenticated
proxy traffic, foreground service connect/disconnect and a request from another
app UID through the actual VPN tunnel. The shared WebView regression test checks
that subscriptions open, copy and close while delay probes remain pending.
`scripts/verify-android.ps1` verifies signatures, package identity, ABIs,
uncompressed native libraries and 16 KiB ELF/ZIP alignment for 64-bit libraries.

The 0.1.20 checks add compressed/redirecting subscriptions during actual Proxy
and TUN connections, direct-network preference and proxy fallback, warm HTTP
measurement, HTTP error/authentication rejection, and orbit motion/occlusion on
the Android 11 / WebView 83 emulator (2 cores, 2 GiB RAM). The reference FlClash
0.8.99 ARM64 APK was inspected statically; its ARM64 UI was not executed in this
x86_64 emulator. Real ARM phones and OEM background behavior remain device checks.

The 0.1.21 regressions also start public-address profiles across four protocols
and five transports, check authenticated URL tests through the full transport
matrix, and verify both automatic modes with a dead first catalog item and a
healthy selected fallback. The tests use synthetic credentials and loopback
servers; no real subscription credentials are included in tests or APKs.
The final owner-signed release passes 12 JVM and 11 emulator tests, including
the authenticated transport matrix and both automatic modes. All five APK
variants pass signature/ABI/native-page-alignment verification. Physical ARM
phones and mobile carrier networks were not available for direct validation.

Before running the native emulator tests, provide the loopback VLESS fixture on
host port 22539, transport matrix 22550–22569 and HTTP 204 fixture on 23040 (test UUID in `NativeSmokeTest`),
with `vyrax-fixture.example` and `203.0.113.1` routed to that HTTP fixture. A
stalled TCP fixture on 22541 keeps the UI regression probes pending. On the
isolated emulator, forward these ports with `adb reverse`, authorize the
test app's VPN via `appops ACTIVATE_VPN`, and push `android/tests/request-tun.sh`
to `/data/local/tmp/vyrax-request-tun.sh`. These checks use synthetic profiles;
never point them at an installed user's app or real subscription store.
`node android/tests/host-fixture.mjs` starts the synthetic host fixtures using
`vendor/xray/xray.exe`; `VYRAX_TEST_XRAY` can select another compatible core binary.
