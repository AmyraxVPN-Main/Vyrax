# Vyrax 0.1.27 — dashboard and connection architecture

This is the first implementation phase of the FlClash-inspired overhaul, not a
complete migration to Mihomo. Existing Xray/sing-box cores, subscriptions, free
accounts, encrypted storage and automatic update notices are retained.

- Shared connection reducer and actions handle cancellation, retry stages,
  stale responses, failed-stop reconciliation and timestamp-based session time.
- Responsive Material dashboard adds real traffic rates, a bounded smooth trace,
  usage counters, transport/strategy cards, subscription access and an accessible
  play/pause connection button. Desktop opens wide and supports maximize/restore.
- Searchable server picker supports live switching, keyboard navigation,
  animated opening/closing, Persian RTL and reduced motion.
- Delay batches use two mobile or three desktop workers, publish results as
  they arrive and keep dialogs usable while tests continue.

All new logic/UI is independently implemented under Vyrax's MIT license. The
reference's GPL code/assets/binaries are not copied into the release. Advanced
Mihomo routing/group/inspector capabilities remain mapped, not simulated, in
`flclash-merge.md`.

Local review artifacts: Windows NSIS installer plus owner-signed Android
arm64-v8a, armeabi-v7a, x86, x86_64 and universal APKs. These files have not been
published to GitHub. Linux/macOS native packages and signed iOS distribution
require their separate platform build/validation stages.

Validation: 49 Node tests, 44 release checks, subscription migration/protocol
roundtrips, 70 native settings, 25 routing-pool, 28 HTTP-delay checks and 13 Android
unit tests passed. Production UI build and Android vital lint passed. Windows
icon/manifest/copyright and Android signing/ABI/assets/alignment are verified.
Browser fixtures cover small/tall phones, landscape/tablet and desktop, both
directions and light/dark. No real accounts or device routing were used for UI
tests; real-device animation smoothness remains to be measured.
