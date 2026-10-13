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

All variants share the application ID `com.amyrax.vyrax` and versionCode 18.
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

Before running the native emulator tests, provide the loopback VLESS fixture on
host port 22539 and HTTP 204 fixture on 23040 (test UUID in `NativeSmokeTest`),
with `vyrax-fixture.example` and `203.0.113.1` routed to that HTTP fixture. A
stalled TCP fixture on 22541 keeps the UI regression probes pending. On the
isolated emulator, forward those three ports with `adb reverse`, authorize the
test app's VPN via `appops ACTIVATE_VPN`, and push `android/tests/request-tun.sh`
to `/data/local/tmp/vyrax-request-tun.sh`. These checks use synthetic profiles;
never point them at an installed user's app or real subscription store.
`node android/tests/host-fixture.mjs` starts the synthetic host fixtures using
`vendor/xray/xray.exe`; `VYRAX_TEST_XRAY` can select another compatible core binary.
