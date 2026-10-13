# Vyrax 0.1.13

The Persian locations screen now follows right-to-left layout for search,
subscription selection, automatic selection cards, delay testing and tabs.
The animated tab indicator mirrors the tab order when the language changes.
Server hostnames and subscription names keep their own text direction.

Subscription import and refresh now read the provider's display name from
`profile-title`, profile metadata comments or the download filename. UTF-8,
base64 and percent-encoded names are supported. Existing subscriptions saved
with a hostname receive a background metadata lookup; this changes labels and
available usage data without replacing servers or changing live routing.
Unavailable metadata preserves the saved name, link fragment or hostname.

The add-subscription button has a fixed minimum height and horizontal padding,
so its label and icon have sufficient space in both Persian and English.

## Validation

- Subscription migration, source isolation, refresh identity, metadata decoding,
  URL validation and invalid-refresh checks passed.
- The compiled production Windows host fetched local HTTP fixtures successfully,
  retaining `profile-title`, `Content-Disposition` and UTF-8 response bodies.
- Production UI build and native preview build passed.
- Persian browser preview verified mirrored controls and tab animation, the
  background recovery of a provider name and preservation of the existing server
  list. The add button measured 176 by 42 pixels with 20-pixel horizontal padding.
- Independent native WebView2 preview checked in Persian and English at
  380 by 646 pixels, including the subscription picker, mixed-language names,
  subscription cards, add button and switching the language in both directions.
  Screenshots are saved as `release/preview-0.1.13-*.jpg`.
- Installer and executable icon resources and administrator manifests passed
  verification. File hashes are in `release/verification-0.1.13.json`.

The browser session was lost during follow-up English validation and its recovery
action was blocked by browser security. English validation was completed in the
independent native preview. No blocked browser action was retried or bypassed.

All visual and fetch checks used fixture subscriptions. The installed application,
user subscriptions, system proxy and current VPN connection were unchanged.
The installer was built but not installed. A provider must supply name metadata
or a named link for its real subscription title to be available.
