# Vyrax 0.1.28 — reference dashboard geometry

This is a local review build. Nothing was published to GitHub in this iteration.

## Interface

- Rebuilt the dashboard around the supplied FLClash screenshot: a collapsed
  48px rail, a flat window bar, regular 22px page titles and equal card columns.
- At the supplied 609×519 size, the grid starts at (65,105). Its content width
  is 527px. The speed card is 347.33×172px; single cards are 167.67×80px;
  all gaps are 12px. No dashboard scroll is needed at that reference size.
- Grid bands follow the available card width, including when the rail expands.
  Wider desktops get four columns; phones get two, with a horizontal usage card.
- Added original geometric SVG icons throughout dashboard, navigation, server
  selection, subscriptions and common controls. Roboto is bundled from Fontsource
  under OFL; Persian continues to use bundled Vazirmatn.
- The connection glyph folds/rotates between play and pause over 450ms. The
  button measures the runtime label and expands over 200ms. Selection uses one
  moving highlight over 320ms. Shared toggles and segmented controls use CSS
  transforms instead of the previous liquid filter surfaces.
- Traffic has a zero baseline and padded history, preventing a diagonal fill
  before the first sample. Idle graphs clear on disconnect. Numeric latency is
  isolated from RTL text. Traffic units align on the opposite card edge.
- Dashboard edit controls persist visible cards. Added a session detail page,
  retaining server selection, disconnect and the existing IP favourite action.
  The address is labelled as a server address, not a measured public exit IP.
- Added local interface enumeration on Windows, Android, Linux/macOS and iOS.
  The dashboard never substitutes a VPN server hostname for the device's LAN IP.
- Added a working keep-on-top button on Windows and Electron desktops.

## Deliberate functional differences

The app retains its Xray/sing-box architecture and Amyrax MIT code. It does not
include FLClash GPL source, custom assets, or the Mihomo controller. Drawings and
web components were implemented for Vyrax from observed appearance and timing.

Manual/Fastest/Balance retain their actual server-selection behavior; they are
not relabelled Rule/Global/Direct. Proxy and TUN remain mutually exclusive next
connection modes. Network detection tests the selected server's protocol delay;
it is not a public IP geolocation service. Connection shows the VPN session, not
Mihomo's per-flow connections table. The dashboard editor controls visibility;
drag reordering is not included. Remaining FLClash capabilities in the integration
map have not silently been represented as implemented.

## Validation

- Production web build and Windows host/helper/NSIS installer completed.
- 41 Node tests passed, including geometry bounds and morph overshoot checks.
- 70 native settings/routing checks and 44 release/update validation checks passed.
- Android release unit tests and vital lint passed. Five APKs built and passed
  signature, ABI, bundled asset and 16KB native page alignment verification.
- Browser fixture inspected at 609×519, 1040×720, 390×844 and 360×720, including
  Persian RTL and light theme. No horizontal page overflow was observed.
- Verified simulated connect/disconnect, live selection, card visibility editing,
  rail expansion and opening subscriptions during a delayed latency request.
- UI checks used synthetic profiles. No real VPN session, account or system route
  was used or changed. Physical phone frame rates were not measured. iOS source
  and the shared desktop shell were updated, but no new signed Apple or Linux
  installer was built on this Windows host in this iteration.

Screenshots and geometry readings are under `.tools/previews/vyrax-0.1.28-*`.
Windows: `release/VyraxSetup-0.1.28.exe`.
Android: `release/android-0.1.28/` (arm64-v8a, armeabi-v7a, x86, x86_64, universal).
