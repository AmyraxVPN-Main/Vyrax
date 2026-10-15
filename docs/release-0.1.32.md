# Windows 0.1.32

Complete Windows installer built from project source, including the native host,
VPN helper, Xray, sing-box, Wintun, WebView2 libraries, current UI and licenses.
It does not require the 0.1.31 location update package.
The installer includes a welcome page, license, destination selection and the
standard uninstall entry and shortcuts.

The location importer follows FoxyVPN's public catalog: 33 countries and
Recommended in the captured 2026-10-15 list. On first launch, an existing free
subscription's truncated catalog is upgraded offline before automatic connection.
The migration preserves other subscriptions, account storage, existing selection,
favorites, ping results and settings. It runs once; future live catalog refreshes
are not overwritten by the bundled snapshot. A new installation does not acquire
an account or free subscription automatically.

This installer contains the normal source-built native host. It does not contain
the custom web-protection solver from supplied fixed installers. Real Mozilla
sign-in/entitlement remains unverified and HTTP 406 remains possible. The catalog
migration does not grant service access; normal account authorization is required.

Validation uses fixture accounts, offline catalog migration tests, a production
build, PE resource inspection and byte-for-byte checks of extracted payloads.
The installer is never executed against the user's real installation for testing.
