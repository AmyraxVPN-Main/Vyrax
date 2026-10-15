# Mozilla sign-in: current integration boundary

## Confirmed on 2026-10-14

The Windows TLS 1.0 transport problem was fixed in 0.1.29. Unauthenticated
requests now reach Mozilla: the server list returns 200; an empty login POST
returns 406. No real account credentials were used in these checks.

The supplied FoxyVPN source treats 406 as a web-protection challenge. This is
distinct from a JSON account/region denial, incorrect credentials or exhausted
quota. Vyrax now reports `err.freeChallenge` independently on all supported
provider hosts. Account state is preserved and credentials are not retried.
The reference's automatic challenge-solving code is not included.

## Browser sign-in prerequisite

Mozilla's public client metadata at
`https://oauth.accounts.firefox.com/v1/client/5882386c6d801776` identifies the
current compatibility client ID as **Firefox**, with registered redirect URI
`urn:ietf:wg:oauth:2.0:oob:oauth-redirect-webchannel`.

That is Firefox's browser integration, not a registered Vyrax callback. Opening
the Mozilla account website does not create a Vyrax session or transfer cookies
to its native HTTP clients. The UI labels this action as checking the account,
and does not promise that website sign-in unblocks the app.

The owner confirmed that Vyrax has no registered OAuth client. Before shipping
browser authorization, obtain a client registration controlled by Vyrax and
confirm Mozilla permits that client to request
`https://identity.mozilla.com/apps/vpn`. Ordinary OpenID profile/email access
alone does not establish Firefox VPN entitlement.

Mozilla's discovery document is available at
`https://accounts.firefox.com/.well-known/openid-configuration`.
An eventual browser integration must use the approved client flow, registered
redirect URI, state validation and PKCE if supported by that registration. Do
not invent a callback for the Firefox client, embed a confidential client secret
in distributed binaries, or extract tokens from a user's browser profile.

Direct credential sign-in can still encounter web protection. Its rejection
is not fixed by the error-display changes; a successful real-account login has
not been verified.
