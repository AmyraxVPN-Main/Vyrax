# Vyrax 0.1.29 — Windows Firefox sign-in transport

The Windows free-server sign-in displayed `err.freeNetwork` before Mozilla could
return an HTTP response. The .NET Framework host defaulted to SSL 3.0/TLS 1.0;
unauthenticated diagnostics reproduced `SecureChannelFailure` with the previous
handler and received HTTP responses with explicit TLS 1.2.

All Windows Firefox/Guardian requests now share a TLS 1.2 handler. Requests use
the active Vyrax control proxy when connected and the system proxy otherwise.
Certificate validation remains enabled; cookies and redirects are disabled.
Endpoint allowlists, account storage and login derivation are unchanged.

The shared login handler now preserves HTTP eligibility/rate-limit errors when
the service sends an empty or HTML response. It does not retry credentials or
mislabel those denials as an unusable JSON response. An empty unauthenticated
login probe received HTTP 406 on this machine; this confirms transport access,
not account eligibility or successful authentication.

Validation:

- 17 native checks passed, covering both routing modes, TLS, credential
  redirects, account lifecycle, quota, secret isolation and online transport.
- Opt-in online checks access Mozilla's official server list and send an empty
  login request (no email/password) to check the real provider HTTP path.
- All 42 Node tests and 44 release validation checks passed. The Windows host,
  helper and production UI built successfully. No real account sign-in was
  performed.
- NSIS installer built successfully; embedded app/installer icons, execution
  levels, copyright and installer version were verified. Artifact hashes are
  recorded in `release/verification-0.1.29.json`.

Windows installer: `release/VyraxSetup-0.1.29.exe`.
Bundle: `release/Vyrax-0.1.29-mozilla-fix/`.
This is a local Windows patch build; no GitHub release or other platform build
is produced by this fix.
