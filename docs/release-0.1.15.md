# Vyrax 0.1.15

TUN transport-server DNS no longer depends on the Windows resolver after the
VPN installs its routes. The previous configuration used the system resolver
for domain-based Xray servers, while sing-box hijacked system DNS and sent it
through those same servers. That creates a bootstrap dependency when cached
answers expire. The user's failed log showed a live TUN interface, a working
initial proxy check, repeated DNS packets, and timed-out TLS checks after TUN
startup. The selected server uses a hostname. This release fixes that dependency;
the user's physical TUN connection has not yet been retested.

Before creating TUN, Vyrax captures an active non-tunnel uplink and its DNS
servers. Xray resolves transport hostnames through a dedicated bootstrap
outbound bound to that uplink, racing network DNS with two HTTPS resolvers.
The transport sockets also bind to the uplink. Forced IP resolution prevents
fallback into Windows DNS. IPv4 is preferred, with an IPv6 DNS fallback.
Application destination names continue through the proxy, and TLS SNI retains
the original transport hostname. Saved profiles are not rewritten. Proxy mode
keeps its previous behaviour.

Routing pools preserve the bootstrap outbound and binding across manual,
automatic and balanced routing, including servers added through the live API.
Split/bypass rules cannot redirect bootstrap DNS into the VPN. The real TUN TLS
verification remains mandatory; an interface or open TCP socket alone cannot
mark the VPN connected. Xray warnings/errors now join the tunnel diagnostic log,
and core errors omitted from the head/tail excerpts are retained separately.

## Validation

- 24 bootstrap checks passed using the bundled Xray, local DNS and actual VLESS
  protocol capture servers. The legacy transport failed to use the independent
  resolver; the corrected transport succeeded with ordinary direct traffic
  blocked. A dead first resolver did not delay the healthy second resolver.
  Bootstrap routing, retained SNI, application-domain isolation, live addition,
  no-op refresh, and production HTTPS configuration acceptance were checked.
- The IPv6 transport integration case is explicitly skipped on this host:
  Windows rejects even an unbound IPv6 loopback TCP connection with WSAEACCES.
  Configuration acceptance is checked; physical IPv6 connectivity is not proven.
- 25 routing-pool checks, 70 settings checks, four process-routing checks and
  seven TLS/concurrent-probe/cancellation checks passed.
- Production UI, native host and helper builds passed. Installer and executable
  manifests/icon resources were checked; hashes are in
  `release/verification-0.1.15.json`.

Read-only diagnostics with an isolated Xray observed transport DNS answers after
adding HTTPS bootstrap alternatives, but all external health checks still failed
under the currently active FlClash TUN. FlClash was enabled after the user's
original failed attempt and is not attributed as its cause. No successful live
TUN reconnect is claimed. The active VPN, installed application and saved user
profiles were not changed. The new installer was built, not installed.
