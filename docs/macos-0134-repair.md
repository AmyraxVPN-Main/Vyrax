# macOS 0.1.34 repair

The supplied Intel app is the application resource baseline for both builds.
`VYRAX_APP_OVERLAY` points to an extracted Resources directory containing `app`,
`native/geo.bin`, `Vyrax.icns`, and `licenses`. The build copies these resources
and replaces only `app/linux/config.mjs`, adding `firefox-tls.mjs` and its public
certificate roots. The existing UI, account modules, subscription handling and
stored-account format are preserved. Verification compares the original files
byte for byte. The UI is not rebuilt from the older workspace sources.

Networking changes:

- Transport bootstrap DNS retains parallel public DoH and also permits OS DNS.
- Firefox CONNECT uses four public GlobalSign roots in addition to system trust.
  Hostname verification, HTTP/2 ALPN and `allowInsecure: false` remain enabled.
- Xray v26.3.27 is rebuilt with the literal-header regression fix. Observatory
  requests have no inbound socket; static authorization headers no longer require
  that context. Dynamic templates still require their original context.

Intel uses x86_64 Electron, Xray, sing-box and native helpers. Apple Silicon uses
arm64 versions of every executable. Helpers are compiled on native macOS runners.
The signed sing-box digest is generated before compiling the privileged helper.
Components are signed from the inside out; the final app is verified with
`codesign --verify --deep --strict`. ZIP creation preserves executable modes and
framework symlinks; DMGs include an Applications shortcut.

Verification is performed on disposable macOS 15 runners. The native integration
test checks Proxy/TUN, HTTPS, delay, compressed subscriptions while connected,
live selection, settings restoration, helper crashes and rollback recovery.
The separate Firefox test uses a local TLS/H2 CONNECT server and synthetic
credentials. It checks blocked-DoH fallback, delay, automatic pool population,
rejection of invalid credentials/certificates/hostnames, and TUN HTTPS.
No real Firefox account or account sign-in endpoint is used by these tests.
Sandboxed Electron testing checks the supplied UI, Keychain encryption, clipboard,
QR, dialog closure during a stalled delay test, Persian RTL and clean Quit.

These packages require macOS 13 or later. They use ad-hoc signatures; they are
not Developer ID signed or Apple notarized. A first launch confirmation may be
required by macOS. The native authorization dialog and a real account login
remain checks for a physical Mac. Test reports accompanying the packages record
the actual outcomes separately for each architecture.

The exact modified Xray source, upstream sing-box source and licensing notices
accompany the packages. See `macos-sources.md` for rebuilding and signing order.
