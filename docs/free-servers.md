# Free servers

Vyrax uses FoxyVPN's Firefox Accounts and Mozilla Guardian flow, then connects
to the official Firefox VPN HTTP/2 CONNECT edges with its existing Xray core.
It does not scrape public configuration links or provision its own VPN service.

The app has a separate, translated guide, email verification, explicit allowance
activation, quota refresh, up to ten saved accounts, account switching, and removal
from the device. Passwords and pending Firefox sessions are never written to disk.
Access/refresh credentials are saved separately from subscriptions using the
platform's encrypted storage. Proxy passes are obtained at runtime and never
exported in subscription links or QR codes.

Endpoints match the supplied FoxyVPN source:

- Firefox Accounts: `https://api.accounts.firefox.com/v1`
- Guardian: `https://vpn.mozilla.org/api/v1/fpn/{status,activate,token}`
- Server list: Mozilla Remote Settings `main/vpn-serverlist/records`

Only non-quarantined CONNECT edges in the official list are used. Like FoxyVPN,
the catalog includes locations marked `locked` in public Remote Settings data;
this metadata is preserved and does not replace server-side account authorization.
`CatchAll Anycast` is omitted, and `REC` is shown as Recommended rather than an
unknown country. Country and city codes are retained, with city codes shown when
the upstream city name only repeats the country name. The free service's advertised
allowance is up to 50 GB/month for eligible accounts. The UI shows actual
`X-Quota-Limit`, `X-Quota-Remaining`, `X-Quota-Reset`, and `maxBytes` responses,
including an unknown state when the service does not report them. Refresh shows
the current server-reported amount rather than estimating it from device traffic.

This is TCP-only HTTP/2 CONNECT. Android device DNS uses DoH through the selected
upstream; Windows/Linux/macOS TUN already use protected DoH. Unsupported UDP is
not sent directly to the internet. Games or calls that require UDP may not work.
Availability and entitlement are controlled by Mozilla. Redirects carrying
credentials and arbitrary proxy hosts are rejected. Web protection challenges
are reported to the user; downloaded JavaScript is not executed.
HTTP 406 is reported separately from account/region eligibility denials, with
an official-site account-check action. This does not transfer a browser session
to the app. See `docs/mozilla-sign-in.md` for the confirmed sign-in limitation
and the prerequisites for an approved browser authorization flow.

Windows uses explicit TLS 1.2 for all provider requests, including login,
verification, quota and pass renewal. Its legacy .NET Framework defaults would
otherwise negotiate TLS 1.0 and fail before receiving an HTTP response. While
connected, requests use Vyrax's local control proxy; otherwise the system proxy
is respected. Cookies and redirects are disabled, and normal certificate
validation remains enabled.

Windows and Electron renew the proxy pass and update live routing for new flows.
Android's native foreground service renews independently of the WebView and
restarts the core when a new pass is needed, so a brief reconnection may occur.
Switching/removing the active account disconnects its free connection. Removing
an inactive account leaves the active connection alone. A different subscription's
connection and stored profiles are preserved.

Implemented hosts: Windows, Android, Linux, macOS and the development iOS host.
The browser preview shows the guide but does not accept account credentials.
iOS uses native CryptoKit derivation for WebKit versions without SubtleCrypto,
stores accounts separately in the encrypted App Group vault and resolves proxy
passes inside the native host/Packet Tunnel process. Its extension renews passes
independently of the foreground UI. Device installation still requires Apple's
VPN signing/provisioning; an unsigned archive is not an installable iPhone app.
An authenticated integration check requires an eligible Firefox account; mocked
protocol/config tests cannot confirm the service grants access to a real account.

See `third_party/FoxyVPN-MIT.txt` and `THIRD_PARTY_NOTICES.md` for source credits.
