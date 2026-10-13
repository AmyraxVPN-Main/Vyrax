# Android library source and relinking

Vyrax application source is MIT, Copyright (c) 2026 Amyrax. Third-party native
libraries retain their own copyright and license. The Android release directory
includes exact upstream source archives for AndroidLibXrayLite and Xray-core,
plus full license notices inside the APK. Keep those files with binary distributions.

Pinned native sources for the 0.1.21 Android build:

| Component | Source commit | License |
| --- | --- | --- |
| AndroidLibXrayLite 26.3.27 | `880725442c1d4023a973ccbcdbf527c89ef83a32` | LGPL-3.0 |
| Xray-core 26.3.27 | `d2758a023cd7f4174a5a5fa4ff66e487d4342ba0` | MPL-2.0 |
| hev-socks5-tunnel 2.18.0 | `d9dca26c7ad0e494492244f0309e80ee583e739e` | MIT |

AndroidLibXrayLite's exact Go module dependencies are pinned by `go.mod` and
`go.sum` in its source archive. Go downloads those source modules and checks
their recorded hashes. Its upstream build workflow is included in the archive.
The original native build uses Go 1.26, Android NDK 28.2.13676358, gomobile and
Android SDK. For a modified library, extract the archive, make changes, then:

```sh
go install golang.org/x/mobile/cmd/gomobile@v0.0.0-20260312152759-81488f6aeb60
gomobile init
mkdir -p assets data
bash gen_assets.sh download
cp data/*.dat assets/
go mod download
gomobile bind -v -androidapi 24 -trimpath -ldflags='-s -w -buildid=' ./
```

To link a modified, interface-compatible AAR into Vyrax, replace
`vendor/android/libv2ray.aar` (or `hev-socks5-tunnel.aar`), set `JAVA_HOME` and
`ANDROID_HOME`, and build from the complete Vyrax source archive:

```powershell
npm ci
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-android.ps1 -UsePreparedLibraries
```

`-UsePreparedLibraries` deliberately skips original-release hash checks for
modified local AARs. Generated APKs use the local development signing key.
For a release build, provide your own keystore/password environment variables
described in `docs/android.md` and add `-Release`. The Amyrax private signing key
is neither needed nor included. Android requires uninstalling a differently
signed existing package before installing a modified APK with the same package
ID; save your configuration first. There is no additional application lock
against installing or using a modified build.

Library rebuilds and Android APK builds have separate toolchain requirements:
the Vyrax Java host uses JDK 17, Gradle 8.9 and Android platform/build-tools 35.
