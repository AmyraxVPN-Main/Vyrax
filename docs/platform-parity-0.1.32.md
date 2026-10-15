# Platform parity — 0.1.32

Windows, Android, Linux, macOS and the iOS host use the same 0.1.32 shared UI:
dashboard, icons, animation timing, Persian/English layout, connection state,
subscriptions, latency batching and automatic/manual update checks.

The Foxy-derived public catalog includes 33 countries and Recommended in the
2026-10-15 snapshot. Existing truncated catalogs are upgraded offline on first
launch while preserving selection, settings, other subscriptions and favorites.
Later live refreshes are not replaced by the snapshot. All native providers now
confirm an empty activation acknowledgement with an official status request,
refresh quota after confirmed access, preserve confirmed entitlement if quota
fails and report unconfirmed access explicitly. This matches Windows 0.1.32.

Android outputs use the existing owner key and application ID, versionCode 32,
and ARM64 v8a, ARMv7, x86, x86_64 and universal architectures. Linux builds target
x64/ARM64 DEB and portable packages. macOS builds target Intel/Apple Silicon DMG
and ZIP packages and remain ad hoc signed rather than notarized.

iOS marketing version is 0.1.32 and build number is 32. Its device archive remains
unsigned and requires Apple VPN signing/provisioning to install. Simulator output
is for host/UI tests and does not provide a real-device VPN integration result.

Builds use project source; no custom challenge solver is included. Real-account
Mozilla authorization is unverified on every platform and may return HTTP 406.
Contract checks use synthetic responses and cannot establish account eligibility.

Build IDs, test results, output paths and checksums are recorded in the 0.1.32
platform build report delivered with the packages.
