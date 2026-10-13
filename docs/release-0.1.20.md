# Vyrax 0.1.20

Android now starts in TUN mode on a fresh install, retaining an existing user's
saved mode. The interface uses light CSS motion instead of large SVG gooey
filters: quick-server buttons travel out from behind the opaque dial, the hero
moves with a transform, and tab/setting controls animate without geometry polling.
Offscreen list painting is skipped on supporting WebViews. Background UI timers
and rendering pause while the native VPN continues running.

URL delay tests use real authenticated HEAD requests through each profile, the
same default 204 endpoint as FlClash and a warmed second request. HTTP errors or
authentication failure yield Timeout; a failed second request retains the first
successful measurement. Probes have an eight-second network budget, lightweight
core configs and bounded concurrency, reduced on low-RAM Android devices.

Subscription refresh while connected now tries the uplink first and the chosen
proxy next. On Windows/Linux a dedicated loopback-only core inbound routes this
management request outside the TUN; ordinary app traffic remains governed by the
existing VPN/routing settings. Android uses its already-excluded host UID. Gzip,
redirects, provider title/usage headers, fresh contents and size limits are retained.
No VPN reconnect is needed to download a subscription.

The Android release is signed with the same owner key as 0.1.18 (versionCode 20).
An in-place signed release upgrade was tested with the encrypted store retained.
An unknown-source/Play Protect installation prompt is controlled by Android/Google;
valid release signing does not guarantee removal of this external trust prompt.

Validation: ten Android JVM tests; eight Android 11 / WebView 83 emulator tests,
including real Proxy/TUN traffic, foreground/background lifecycle, connected
subscription refresh, proxy fallback, delay failure handling and orbit motion;
Windows synthetic direct/proxy subscription tests without changing OS networking;
Linux isolated network namespace tests of actual Proxy/TUN and both subscription
paths, routing, IPv6/DNS and seamless selection; seven Linux unit tests. ARM APKs
and Linux ARM64 packages receive structural verification; physical ARM phone/desktop
performance and OEM background restrictions require device testing.

MIT application copyright: 2026 Amyrax. Third-party licenses remain unchanged;
the Android HTTP transport also bundles Apache-licensed OkHttp/Okio/Kotlin notices.
