# Retirement Plan

This is a portfolio demonstration piece, not a production product, so
"retirement" here means what it would take to cleanly archive or remove
it, not a customer-facing sunset process.

## If this repo is retired

1. Archive rather than delete the GitHub repository, so the portfolio's
   history (including the ADRs documenting real engineering tradeoffs
   made here) remains inspectable.
2. No production data to migrate or destroy - this app stores nothing
   server-side of its own (notifyhub owns all persisted state) and only
   the Keychain-held JWT locally, which is meaningless once notifyhub
   itself is retired or the token expires.
3. If notifyhub (the backend) is retired first, this app has no
   independent purpose - it is explicitly a companion app
   (see [01-brief.md](./01-brief.md)) and should be retired in the same
   pass, not kept alive pointing at a dead backend.
4. Revoke/delete any real APNs key material an operator may have used
   for physical-device testing (this repo/session never held any such
   material itself - see [04-security.md](./04-security.md) - but an
   operator who did real device testing outside this sandbox is
   responsible for their own key hygiene).

## Coupling to notifyhub

This app and notifyhub are a deliberately coupled unit
(`ApnsPushChannel` on the backend has no consumer without this app; this
app's push story has no backend without notifyhub's device-token
mutations). Any retirement or major-version decision for one should
consider the other - see notifyhub's own
`docs/project-memory/11-retirement-plan.md` for its side of this.
