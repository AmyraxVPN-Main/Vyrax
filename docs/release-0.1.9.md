# Vyrax 0.1.9

- Account content is vertically balanced as a group. The version follows the final button by 12px (10px in compact windows), without scrolling at 380×646 and 320×568.
- Frameless MainForm retains native WS_MINIMIZEBOX and WS_SYSMENU styles, enabling the standard Windows taskbar minimise behaviour.
- All five formerly disabled settings are implemented. Older disabled true defaults migrate to off so updating does not unexpectedly start a connection.
- Auto-connect restores the selected saved server once on launch. Native auto-reconnect handles core exits and repeated failed connectivity checks, with 2–30 second backoff. Manual disconnect, cancel, exit and server switches invalidate pending attempts. Permanent configuration/sharing errors are reported without endless retries.
- Split/bypass lists accept domains (including subdomains), IPs and CIDR ranges, validate and deduplicate up to 200 entries, and persist in the encrypted store. These two modes are mutually exclusive. Real Xray routing handles both system proxy and the sing-box SOCKS path. TLS/HTTP sniffing allows domain rules for traffic addressed to an IP. Private network destinations remain direct. A dedicated loopback probe always verifies the VPN outbound independently of split rules.
- Sharing uses a separate HTTP listener. Its firewall rule is restricted to the Xray executable, current port, Private Windows networks and LocalSubnet. The active host/port is shown in settings. Disconnect removes the rule; the next sharing session cleans orphan rules belonging to exited instances of the same executable.
- Routing, sharing and mode changes apply on the next connection; auto-reconnect changes apply immediately. UI help states this explicitly.

Validation: production UI/native/helper builds; 68 settings checks, including real Xray + sing-box routing, TLS SNI, domain boundaries, IP ranges, share HTTP routing, startup, retry/cancel and encrypted persistence; previous TUN/probe/helper regressions pass. Persian and English UI, rule validation, mutual exclusion, shared endpoint display and compact Account layout checked with isolated previews.

Limits of this run: no live VPN was restarted and no firewall rule was installed on the user's system. Sharing with a physical second device and clicking the actual Windows taskbar icon were not exercised. The Windows automation interface did not expose the taskbar as a target. An isolated native preview compiled and opened successfully with the new window styles. Existing installed Vyrax/Xray/sing-box processes stayed running.
