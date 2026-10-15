# Vyrax 0.1.30 — identify Mozilla web-protection failures

Mozilla can reject a direct sign-in request with HTTP 406 before returning a
Firefox Accounts JSON response. The UI previously conflated that response with
account or region eligibility. It now reports web protection separately, offers
an explicit official-account-site link, and explains that website sign-in does
not transfer a session to Vyrax.

This build does **not** solve the provider's web-protection challenge or confirm
successful real-account sign-in. Browser OAuth is not implemented: the current
compatibility client belongs to Firefox and has a Firefox WebChannel redirect;
Vyrax has no registered client or approved VPN scope. Details and prerequisites
are recorded in `docs/mozilla-sign-in.md`.

Changes:

- Distinct challenge handling in the shared client, native Windows provider and
  Android provider; Linux/macOS use the shared response parser.
- Challenge and transient failures retain the saved account. Sign-in does not
  retry credentials on protection/eligibility failures. The invalid-parameter
  compatibility retry is limited to HTTP 400 with Firefox error 107.
- Malformed successful response bodies produce a controlled service error.
- Translated guidance for Persian/English uses the existing theme and supports
  small screens. No account credentials or browser cookies are imported.

Validation: 45 Node tests, 17 native provider checks, and 14 Android unit tests
passed. UI uses synthetic data with a mocked 406 response; real account sign-in
was not performed.

The production Windows host, helper and UI built successfully. All 44 release
validation checks passed. Browser checks at 643×519 (English desktop) and
390×844 (Persian mobile) confirmed contained layout, visible challenge guidance
and the fixed official-account link. Screenshots are saved under
`release/Vyrax-0.1.30-mozilla-message*.jpg`.
The final NSIS installer passed embedded-icon, execution-level, copyright and
version checks; hashes are recorded in `release/verification-0.1.30.json`.

Local Windows installer: `release/VyraxSetup-0.1.30.exe`.
Bundle: `release/Vyrax-0.1.30-provider-status/`.
No GitHub release or new Android/Linux/Apple installer is published in this fix.
