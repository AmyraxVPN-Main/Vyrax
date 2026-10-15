# Windows 0.1.31

Full Windows installer with the production host, VPN helper, cores, UI, icons
and licenses. It does not require the earlier interface-only updater.

Activation acknowledgements without entitlement data are followed by an official
account status check. Confirmed access immediately requests quota information;
unconfirmed access or a rejected quota request produces a visible error. The
interface shows an activating state, refreshes older native-host responses and
keeps the actual confirmed account state after a quota failure.

Installation overwrites the application payload without recursively deleting the
entire user-selected directory. Saved accounts and subscriptions remain in the
existing per-user data directory.

This build uses the project source, not the third-party challenge solver in the
supplied `fixed` executable. Mozilla HTTP 406 and real-account entitlement are
not resolved by these UI and state-handling changes. Verification uses synthetic
account responses; no real-account activation is claimed.
