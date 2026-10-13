# Vyrax 0.1.22 — Android home layout and animation parity

The Android home dial now shares the Windows liquid silhouette, four-node orbit,
spring motion and staggered opening/closing. The power button masks the flags
until they emerge from its circular edge. A single bounded filter is used for
the dial, without continuous shape observation; other mobile surfaces keep their
lighter renderer.

The connected dial, latency, uptime, traffic, IP and server picker match Windows
geometry at 380 × 646. Tall phones retain those compact proportions, with extra
space around the composition. Short screens adapt to avoid overlapping the IP
and picker. Persian layout stays centred even during rapid orbit toggles;
transient overflow can no longer scroll the whole shell sideways. Older WebViews
receive spacing fallbacks, and reduced-motion users get immediate orbit changes.

Android versionCode is 22. All ABI variants retain the existing owner signing key
and can replace the previous APK in place. Windows/Linux installed binaries are
not replaced by this Android UI update. The connection and delay fixes from
0.1.21 remain included.

Validation details accompany the APKs in `validation.json`. UI coverage includes
comparison with Windows, four phone viewport sizes, English/Persian, intermediate
animation frames, spring overshoot, return masking, rapid toggles, update banners
and reduced motion. Physical ARM phone performance still needs device testing.

Copyright (c) 2026 Amyrax. MIT application source and corresponding native library
sources/relink instructions accompany the Android packages.
