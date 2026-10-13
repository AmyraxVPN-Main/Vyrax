# Vyrax for iPhone and iPad

The iOS host reuses Vyrax's React interface, themes, Persian/English layout,
subscriptions, single-config grouping, QR sharing and published GitHub update
banner. Minimum iOS 16; iPhone/iPad hardware uses ARM64. This is different from
Android APK splits: there is no ARMv7 iPhone build for supported iOS versions.

## Current distribution limit

An unsigned device archive is a developer output, **not an installable IPA**.
The iOS simulator app can demonstrate the UI but cannot establish an iPhone VPN.
No device VPN, background survival, IPv6/DNS or performance claim is made until
the signed app has been tested on an actual iPhone.

Public installation requires Apple signing and provisioning for both the app and
its Packet Tunnel extension, with Network Extension, App Group and shared
Keychain entitlements. A free Personal Team does not provide the required
Network Extension capability. Ordinary users cannot install an unsigned VPN by
opening a GitHub download. AltStore/free re-signing does not grant the missing
VPN entitlement. Do not label these archives as ready for public installation.

The usual distribution route is an Apple Developer Program membership followed
by TestFlight/App Store review. Ad Hoc requires registered device UDIDs and
proper profiles; it is not unlimited public installation. Enterprise certificates
are not a lawful public distribution substitute. Alternative distribution also
has Apple's eligibility, signing and geographic conditions.

## Build on macOS

Install Xcode with an iOS SDK + simulator, Node 22, Go 1.26, Python 3 with Pillow
and XcodeGen. Run `bash scripts/build-ios.sh`, then `bash scripts/test-ios.sh`.
The workflow `.github/workflows/ios.yml` performs these steps on a disposable
ARM64 Mac runner without touching the owner's desktop VPN or private profiles.

Outputs in `release/ios-VERSION` include an unsigned device `.xcarchive.zip`, an
ARM64 simulator `.app.zip`, verification reports, checksums, application sources
and exact dependency source archives. The generated project is
`ios/Vyrax.xcodeproj`; `ios/project.yml` is the tracked reproducible definition.

For a signed build, register `com.amyrax.vyrax`, `com.amyrax.vyrax.tunnel` and
`group.com.amyrax.vyrax` in your Apple team. Enable Packet Tunnel Provider,
the App Group and shared Keychain group on both identifiers. Set
`VYRAX_APPLE_TEAM` before generating the project, select the same team in Xcode,
archive with signing enabled, then use Xcode Organizer to export/upload.
Never commit certificates, profiles, passwords, API keys or device identifiers.
App Store submission also needs the VPN privacy policy, encryption export
classification and compliance with Apple's VPN app review requirements.

## Connection and security

`NETunnelProviderManager` asks iOS for VPN permission. `NEPacketTunnelProvider`
owns the Xray engine and a small hev tun2socks stack in its own process, so the
foreground WKWebView is not the VPN service. Public `NEPacketTunnelFlow`
read/write APIs connect to hev through a bounded datagram socketpair, using the
documented IP packets; there is no private KVC/file-descriptor discovery.
IPv4/IPv6 default routes and DNS are installed by iOS. Extension-originated
upstream sockets bypass its own packet flow under the Network Extension model.

Subscriptions/configs use AES-GCM encrypted files in the App Group; the random
key is in the shared device-only Keychain, available after the first unlock.
Keychain/App Group failures stop storage; there is no plaintext fallback on a
device. Simulator-only storage uses its sandbox and is not a device fallback.
Clipboard exports are local-only and expire. The WKWebView only loads packaged
assets; its bridge accepts main-frame messages from the local app origin.

Delay testing measures an HTTP 204 request through the chosen outbound. While
connected it adds a temporary outbound to the same extension core; it does not
start a second core or ping through the currently selected profile. Two probes
at most run concurrently. Subscription fetching tries extension-originated
direct access, then the selected VPN route; redirects cannot downgrade HTTPS,
and bodies/redirect counts/timeouts are bounded. Network work runs off the UI.

Fastest/Balance use Xray's healthy-outbound observatory and source-scoped router;
switches replace routing for new streams while existing streams continue on their
original server. That cannot guarantee an existing stream survives server loss.
Manual selection turns automatic routing off. iOS uses full-device VPN only;
desktop proxy mode and LAN proxy sharing are not exposed. Optional reconnect is
implemented through iOS VPN On Demand and is disabled on explicit disconnect.

## Licenses

Application/host/adapter code: MIT, copyright Amyrax. Xray-core remains MPL-2.0;
hev/lwIP/libyaml/task-system keep their own included notices. Exact module ZIPs,
source commits, submodule sources and `go.sum` accompany the build. The app's MIT
license does not replace dependency licenses. No desktop sing-box binary or
separate Go runtime is embedded into this iOS host.
