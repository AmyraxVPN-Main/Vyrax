# Third-party notices

Vyrax application code is Copyright (c) 2026 Amyrax and licensed under MIT.
Third-party software keeps its own copyright and license. The MIT license for
Vyrax does not relicense the components below.

## VPN components shipped with the Windows package

- Xray-core 26.3.27: Mozilla Public License 2.0.
  Source: https://github.com/XTLS/Xray-core/tree/v26.3.27
- sing-box 1.14.3: GNU GPL version 3 or later, with its upstream name/association
  notice. Source: https://github.com/SagerNet/sing-box/tree/v1.14.3
- Wintun 0.14.1: upstream prebuilt-binaries license. The driver is distributed
  alongside software using its permitted API. The source project is available
  at https://git.zx2c4.com/wintun/ . The prebuilt binary is not MIT licensed.
- Microsoft Edge WebView2 SDK 1.0.3537.50: Microsoft license terms. WebView2
  Runtime is provided by Microsoft and is not included as a separate installer.

Full component license texts are included in the installed `licenses` folder.
Pinned download locations and archive hashes are recorded in `vendor/versions.json`
in the development workspace and `licenses/versions.json` in binary packages.
When publishing binaries, provide the corresponding source for components whose
licenses require it alongside the binary release; upstream links do not replace
those distribution obligations.

## Interface and data

- React and React DOM 18.3.1: MIT.
- liquid-gooey 0.2.2: MIT.
- qrcode 1.5.4: MIT, plus licenses of its dependencies.
- flag-icons 7.5.0: MIT.
- lucide-react 0.468.0: ISC.
- yaml 2.9.1: ISC.
- ip3country 5.0.0: ISC; supplies the offline country lookup data.
- Vazirmatn 33.0.3: SIL Open Font License 1.1.

Full npm dependency notices are shipped in `licenses`. Build-tool dependencies
retain the licenses listed in their packages and are not relicensed by Vyrax.
The full flag-icons copyright and MIT license for the SVG assets in `public/flags`
also accompany the source tree in `third_party/flag-icons-MIT.txt`.

## Android package

- AndroidLibXrayLite 26.10.10: LGPL version 3. The native library embeds Xray-core
  26.10.10, whose source is covered by MPL 2.0. Both retain upstream copyrights.
  Source: https://github.com/2dust/AndroidLibXrayLite/tree/v26.10.10 and
  https://github.com/XTLS/Xray-core/tree/v26.10.10 .
- hev-socks5-tunnel 2.18.0: MIT, Copyright (c) hev. Source:
  https://github.com/heiher/hev-socks5-tunnel/tree/2.18.0 .
- AndroidX WebKit 1.12.1 and AndroidX support dependencies: Apache License 2.0.
  Android System WebView is provided by the device and is not bundled.

Full Android library license texts are in `third_party/android` and included in
the APK's license assets. Pinned AAR hashes are in `vendor/android-versions.json`.
The application code remains MIT. Android binaries must be accompanied by the
corresponding library source and relinking/build instructions required by LGPL,
including the application source; the Android build accepts replacement AARs.
