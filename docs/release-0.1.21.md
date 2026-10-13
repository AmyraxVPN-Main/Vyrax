# Vyrax 0.1.21 — Android profile compatibility and automatic selection

The Android native core is now the verified official AndroidLibXrayLite/Xray
26.3.27 build, matching the Windows core. The previous Android 26.10.10 build
rejects public-address VLESS without TLS/encryption and Trojan without TLS.
Those configuration errors appeared as Timeout in delay tests and also stopped
Fastest/Balance from starting when one rejected profile was in the catalog.
Imported transport/security settings remain faithful to the provider's profile.
REALITY's missing/empty fingerprint defaults and public-key fields match desktop.

Delay tests use HTTP/1.1 HEAD over SOCKS5 through the authenticated profile, measuring
received target responses like PC/Mihomo, including redirects and HTTP error
statuses. Redirects are not followed. Authentication, CONNECT, TLS and transport
failures remain failures. Warmed measurement, successful-first-result retention,
eight-second deadlines and bounded test concurrency remain intact.
Using SOCKS5 also prevents an intermediate HTTP proxy error from looking like
a successful target HTTP response.

Automatic pools start with the chosen profile as their fallback. Initial
verification retries within the same total deadline if it preceded observatory
results. New connections continue to use leastPing/leastLoad routing; established
connections stay on their existing outbound. Traffic totals and active-node
tracking use the pinned library's per-outbound statistics API.

The Android versionCode is 21 and all APK variants retain the existing owner
signing key. Subscriptions/settings survive an in-place update. Windows/Linux
0.1.20 binaries are not replaced by this Android-specific update.

Validation: 12 JVM tests and 11 tests on the final owner-signed Android 11 / WebView
83 APK. Coverage includes native startup across four protocols/five transports,
20 authenticated URL tests through synthetic transport servers, automatic pools
with a dead first node, connected Proxy/TUN subscriptions and shared WebView behavior.
All five APK variants pass signature, ABI and native-page-alignment checks. A
signed 0.1.20 → 0.1.21 upgrade retains the encrypted test store unchanged.
Physical ARM phone/carrier behavior still requires device testing.

Copyright (c) 2026 Amyrax. MIT application source and exact corresponding native
sources/relink instructions accompany the Android APKs.
