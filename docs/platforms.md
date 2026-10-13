# Platform plan

Windows x64 is the existing desktop release. An Android host/build is implemented
in `android`; see `docs/android.md` for APK architectures and validation limits.
Linux x64 and ARM64 desktop packages are implemented in `linux`; see
`docs/linux.md` for installation, builds and verification limits.
iOS and macOS are planned, not yet shipped.

## Shared application layer

Keep the React screens, theme/animation system, English/Persian translations,
config import/export, subscription grouping, selection state and published-release
validation shared. `src/bridge.js` is the boundary for native services. The central
`project.json` defines the publisher, copyright, license, repository and channel.

Each host must implement storage, clipboard/file import, external project links,
release checks, VPN connect/disconnect, statistics, delay testing and server-pool
selection with the same observable behavior. Native hosts must validate configs
and routing choices rather than trust browser messages. Application data stays
local to the device, with platform secure storage for VPN credentials.

## Platform VPN services

| Platform | Required native integration |
| --- | --- |
| Windows | Existing C# / WebView2 host, Xray, sing-box, Wintun and administrator startup. |
| macOS | A macOS host and signed VPN/network integration; reuse the desktop interface. |
| Linux | Implemented Electron host, GNOME/KDE proxy integration, Xray transports and a Polkit-authorized sing-box TUN lease with IPv4/IPv6/DNS. |
| Android | Implemented Java/WebView host, `VpnService`, foreground notification, Android permission flow, Xray library and hev-socks5-tunnel. |
| iOS | Apple Network Extension / Packet Tunnel Provider, VPN entitlement, signed app/extension and supported core libraries. |

macOS and iOS signing/builds require an appropriate Apple development environment
and entitlements; the Windows helper cannot provide these. Android and iOS need
mobile lifecycle/background handling and layouts tested on real phones. Privilege
and routing changes should stay in native VPN services, not in the interface.

## Delivery sequence

Stabilize and document the shared bridge contract first. Add and test each native
host against its OS's VPN, routing, DNS, storage and permission behavior. Keep
platform assets under the same GitHub release tag so one version check can open
the appropriate release page. Do not advertise a platform as available until its
binary has been built and its real VPN connection tested on that platform.
