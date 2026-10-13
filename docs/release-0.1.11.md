# Vyrax 0.1.11

The connected Home screen removes the JITTER and LOSS cards. Uptime keeps one centred card at the same width as the traffic cards. The server/IP text and favourite button are centred as a single group; removing the empty leading grid column fixes the visible shift to the right.

Delay testing follows FlClash's default URLTest/unified-delay behaviour: HEAD to `https://www.gstatic.com/generate_204` through each tested profile, with an eight-second request budget and no redirects or alternate-URL fallback. The first request prepares the connection; the second measures delay. A successful first measurement is retained if the repeat fails, as in Mihomo. TLS certificate validation remains enabled; the Windows client offers TLS 1.2. Core startup is outside the measured time. The temporary core uses a dedicated probe inbound forced to the tested outbound, and is cleaned up independently of the active VPN session.

Three profile tests run at once because Vyrax starts an isolated Xray process for each test. Results appear as each profile finishes. Pending rows show testing status; failed rows show Timeout. Fastest sorting updates with those results. Vyrax continues to use Xray rather than Mihomo, so this aligns the test method, not the exact numerical result from another core or network session.

Reference source inspected on 2026-10-13:

- [FlClash test defaults](https://github.com/chen08209/FlClash/blob/main/lib/common/constant.dart): default URL and eight-second timeout.
- [FlClash configuration defaults](https://github.com/chen08209/FlClash/blob/main/lib/models/clash_config.dart): unified delay enabled by default.
- [FlClash core test](https://github.com/chen08209/FlClash/blob/main/core/hub.go): URLTest through the selected proxy.
- [Pinned Mihomo implementation](https://github.com/chen08209/Clash.Meta/blob/8597778c7df410ebe88c57e59eaab32d203156df/adapter/adapter.go): HEAD, connection reuse, second measurement and first-response fallback.

Validation:

- 28 delay checks pass: proxy use, HEAD and exact target, warmed timing, any HTTP status, redirects, first/repeat timeout, TLS 1.2/SNI and invalid TLS rejection. Real bundled Xray routing and HEAD forwarding also pass against local capture endpoints; no user profiles or external endpoints were tested.
- Browser fixture confirms per-profile results and Timeout appear while slower tests are still pending. Production App/components are used with an in-memory bridge.
- Home at 380×646 in English and Persian: combined text/button horizontal offset below 0.01px; vertical text clearance differs by less than 0.02px. No Home overflow at this window size. At 320×568 the same centring holds; existing compact Home scrolling remains.
- Native isolated preview confirms the final connected Persian UI; fixture connection performs no network, proxy or TUN actions.
- Production UI/native/helper builds and installer verification pass; all nine icon sizes and the application's administrator manifest are present. See `release/verification-0.1.11.json`.

The installer is built but not installed. The user's installed app and active connection were left running.
