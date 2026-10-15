# Vyrax 0.1.26

Update checks now start immediately when the app opens, independently of loading
profiles. The existing themed, dismissible notice appears only for a validated,
published stable release newer than the installed app. Manual checking in About
remains available.

An unavailable startup check retries silently after 15 seconds, then 1, 5 and
15 minutes. Network recovery and returning to a visible app can trigger another
check; a one-minute cooldown prevents duplicate focus checks. Concurrent manual
and automatic checks share one request. Successful checks retain the existing
12-hour background interval, and dismissing a version still suppresses that
version while permitting notifications for a later release.

This shared UI change applies to all platform hosts. Regression tests cover
startup, offline recovery, retry backoff, focus/visibility, concurrent manual
checks, disposal, React StrictMode and dismissal across releases.
