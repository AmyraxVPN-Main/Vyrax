# Vyrax 0.1.12

The locations screen now offers Fastest and Balance. The subscription picker
keeps each subscription's servers separate and supports selecting, refreshing,
copying the original link, sharing a locally generated QR, and deleting a
subscription independently. Usage and expiry are shown when the provider sends
the corresponding subscription headers. Existing subscription URLs are migrated
to opaque source IDs without changing their links.

## Routing behavior

- Fastest uses Xray's leastPing strategy and healthy HTTP response delay.
- Balance uses leastLoad with two preferred healthy candidates and distributes
  new connections. It does not combine servers' bandwidth for a single download.
- Automatic choices stay within the selected subscription. Choosing a specific
  server, including the currently active one, disables automatic selection.
- Routing and outbound updates use the running core's loopback API. Xray,
  local listeners, system proxy, and the TUN interface are not restarted by
  a server or subscription selection change.
- Existing outbound handlers remain alive until disconnect so existing healthy
  TCP/TLS streams can finish on their original server. If that server physically
  fails, the application cannot preserve those streams. New connections then use
  the selected healthy alternative.
- Observatory checks run every 45 seconds; the displayed target is refreshed
  every 10 seconds. These are response-delay and health checks, not throughput
  benchmarks. The selected server is used as fallback before probe results exist.
- The current catalog is limited to 512 servers. Up to 2,048 outbound versions
  are retained in one connection session; reconnecting clears older versions.
- Selection policy and source survive settings saves, restarts, and automatic
  reconnects. Invalid or empty refresh results do not replace an existing source.

## Additional fixes

Windows local ports are checked for both TCP and UDP availability. A port may be
available for TCP but reserved for UDP, which previously caused intermittent core
startup failures. Recent allocations also remain distinct within the process.

The Windows icon now uses a mirrored, optically centred mark and supersampling
at nine sizes from 16 to 256 pixels. The account logo has a matching optical
alignment adjustment. The build generates the icon before bundling the UI.

The QR dialog retains keyboard focus when its contents change and keeps its
copy/back controls wide enough to avoid wrapping.

## Validation

- 22 routing-pool checks with the actual bundled Xray and local capture servers:
  automatic selection, failed-node exclusion, balanced new flows, manual pinning,
  source isolation, live additions, failed-update preservation, unchanged core
  process, and survival of a held TCP stream across selection changes.
- 70 settings/session checks, including JSON bridge round trips, scoped automatic
  startup, manual intent after reconnect, and actual Xray/sing-box routing chains.
- 28 HTTP delay checks and 8 tunnel routing/TLS/cancellation checks passed.
- Helper framing/token checks and subscription migration/scope/header/URL checks
  passed.
- Production React UI checked in Persian and English at the 380 × 646 Windows
  layout; connect, Fastest, Balance, manual selection, source switching, refresh,
  copy feedback, two-step deletion, QR, keyboard trapping, and Escape exercised.
  No browser warning/error logs were recorded.
- An isolated native WebView2 preview was checked. Its QR screenshot was decoded
  by OpenCV to the exact original fixture URL.
- Installer and executable resources verified against all nine generated icon
  frames; application administrator manifest and installer user manifest checked.
  Hashes are recorded in `release/verification-0.1.12.json`.

The native preview uses fixture subscriptions only. No user configuration, system
proxy, installed application, or physical TUN connection was changed during this
validation. The new selection feature has not been exercised with a real user
subscription or a physical TUN session. The installer was built but not installed.
