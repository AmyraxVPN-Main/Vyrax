# Windows 0.1.31 location catalog update

The supplied FoxyVPN `ServerListClient.kt` uses Mozilla Remote Settings and
excludes only `CatchAll Anycast` from its location catalog. Vyrax additionally
discarded every record with `locked: true`, leaving seven of the 34 catalog
entries returned on 2026-10-15. The importer now includes all 33 countries and
Recommended, preserves the upstream flag as metadata, and still requires the
provider's account authorization to connect. Quarantined servers, incompatible
protocols and hosts outside the permitted provider domain remain excluded.

Recommended has a translated group at the top of Locations. Country/city codes
are preserved and city codes distinguish entries whose upstream city name only
repeats the country name. Refreshes retain stable IDs, favorites and ping results.
The shared importer applies to all hosts when they build the updated UI.

`scripts/installer-locations-update.nsi` builds an update for existing Windows
0.1.31 installations. It contains only the UI built from this repository and
does not include or overwrite any executable, core, account vault, subscription
store or native login module. The supplied fixed installer's 274 UI files were
identical to the source-built 0.1.31 UI. No external native executable was used.
After applying the update, refresh the Free servers subscription to replace its
previously saved list. This catalog change does not test or grant account access.

Regression tests use a public, unauthenticated Mozilla snapshot in
`tests/fixtures/mozilla-locations-2026-10-15.json`. No account request or real VPN
connection is needed for this verification.
