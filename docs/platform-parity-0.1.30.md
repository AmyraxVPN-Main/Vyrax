# Platform parity — 0.1.30

All platform packages use the same 0.1.30 React dashboard, icons, animation
timings, Persian/English layouts, subscriptions, connection state handlers,
latency batching and startup/manual update checker. Desktop window controls and
system VPN permission flows remain native to each operating system.

Android includes ARM64 v8a, ARMv7, x86, x86_64 and universal owner-signed APKs.
Linux includes x64/ARM64 DEB and portable archives. macOS includes native Apple
Silicon/Intel DMG and ZIP packages; these remain ad hoc signed, not notarized.

The iOS host now implements the same Firefox account actions, separate encrypted
account storage, quota, account switching/removal and native pass resolution.
CryptoKit implements the existing authPW/Hawk vectors when local WebKit does not
expose SubtleCrypto. Provider requests are bounded to the fixed Mozilla endpoints;
credential redirects and cookies remain disabled. Passes are injected into Xray
only in native memory, and renewed by the Packet Tunnel extension. Account vault
operations use an interprocess lock to prevent an in-flight renewal from restoring
an account after it is removed.

HTTP 406 continues to mean that Mozilla web protection blocked the request. This
work does not solve that challenge or confirm real-account authentication. No
automated real login, browser cookie import or challenge solver is included.

iOS outputs are an unsigned ARM64 device archive and an ARM64 simulator app.
They are developer/test outputs, not a publicly installable IPA. Device VPN and
background operation still require appropriate Apple signing and real-device tests.

Build results and artifact hashes are recorded with the platform outputs under
`release/`; the Windows 0.1.30 installer is preserved.
