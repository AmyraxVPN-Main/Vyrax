# Vyrax 0.1.14

Connection verification now races independent health destinations and accepts
the first verified response. Losing probes are cancelled and drained before the
operation returns. TLS authentication and verification through the actual TUN
interface remain required. The user's successful tunnel log showed a 12-second
TLS timeout on the first destination before the second destination succeeded;
that ordering no longer forces a healthy connection to wait for a blocked target.
The display address resolves asynchronously, with session and selection guards,
instead of delaying connection completion or server selection.

Subscription names now prefer a specific name over generic provider titles such
as `Subscription`. Read-only inspection of the affected provider response found
a generic base64 `profile-title` and the correct `Amyrax-100GB-V2` filename in
`Content-Disposition`. Both import/refresh and background recovery of previously
saved generic names use the corrected precedence.

Subscription downloads reuse HTTP transport connections, support gzip/deflate and
retain per-request deadlines, redirect checks and the decompressed size limit.
Concurrent UI requests for the same link share an in-flight download; contents
are not cached between refreshes. A refresh with identical outbound configurations
and selection skips routing API commands while updating display metadata. Existing
subscription cards retain their order, and the refresh control shows progress.

Copy and refresh notifications appear above the open subscription panel. Refresh
completion has its own translated message. Search focus uses a subtle outline
around the rounded search container without a rectangular outline on the input.

## Validation

- Subscription name/migration/scope/refresh/URL checks passed, including the
  affected provider's generic title and actual filename combination.
- 25 routing-pool checks passed with the bundled Xray and local capture servers,
  including no routing revision for an unchanged refresh, updated labels,
  live changes and survival of existing TCP streams.
- Four tunnel process-routing checks, four TLS/cancellation checks and three
  concurrent-probe checks passed. A healthy second check completed in 91 ms
  while both 12-second losing checks were cancelled and drained. This is a
  controlled test, not a measured connection time on the user's VPN server.
- Compiled production fetch checks passed for headers, UTF-8, compressed body
  decoding and two fresh responses over one reused HTTP connection.
- Isolated native WebView2 preview checked in Persian and English: recovery of
  the provider name, rounded search focus, copy feedback above the panel, refresh
  progress/completion and preserved card order. The preview uses an in-memory
  clipboard and subscription responses; it does not replace the Windows clipboard.
- Production and preview builds passed. Installer/executable icon resources and
  manifests were verified; hashes are in `release/verification-0.1.14.json`.

The installed application's logs and provider metadata were read only. No user
configuration, live VPN session or system proxy was changed. The installer was
built but not installed. Final connection and download time still depends on
server and network response; a real reconnect was not attempted during validation.
