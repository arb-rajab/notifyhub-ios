# Brief

## What this is

notifyhub-ios is a native Swift/SwiftUI companion app to
[notifyhub](https://github.com/arb-rajab/notifyhub), demonstrating:

- A native GraphQL client (hand-rolled, not a generated/heavy client
  library) against notifyhub's single `/graphql` endpoint.
- A native `graphql-transport-ws` subscription client for notifyhub's
  real-time `notificationReceived` subscription.
- Real APNs device push end-to-end: registering a device token against
  notifyhub's new `registerDeviceToken`/`rotateDeviceToken`/
  `revokeDeviceToken` mutations (added to notifyhub specifically for this
  app - see notifyhub's ADR-008), and deep-linking from a push in every
  app state (foreground, background, killed) into the right
  channel/notification.

This app is the second half of one coupled unit of work: notifyhub's
`ApnsPushChannel` has no reason to exist without a real client consuming
it, and this app's entire reason for existing is demonstrating that
channel actually working.

## Portfolio context

Per the portfolio's mobile-coverage plan, this is one of two
native-mobile repos (alongside `lexicon-android`) - cross-platform
(React Native/Flutter/etc.) is the deliberate pattern everywhere else in
the portfolio, so native Swift/SwiftUI is the intentional choice here,
not an oversight.

## Non-goals

- **Not** a general-purpose GraphQL client library - the networking layer
  is sized to exactly what notifyhub's schema needs, not a reusable
  abstraction.
- **Not** offline-first in the sense `lexicon-android` is (that app's
  brief calls for it explicitly; this app's brief does not) - there's no
  local persistence layer or sync engine here, only in-memory state for
  the current session plus the Keychain-stored JWT.
- **Not** a vehicle for verifying real APNs delivery - that's a permanent,
  by-design limitation of any automated/sandboxed session (see
  [07-decisions.md](./07-decisions.md) and [08-risk.md](./08-risk.md)).

## Repository bootstrap note

This repository had zero commits and zero branches on GitHub when this
session started - not even an initial README. The first commit on this
branch establishes a minimal `main` (license, gitignore, stub README) so
`main` and the feature branch share real history, matching how
`pulsewatch-mobile` handled the same situation elsewhere in the
portfolio. See [12-session-handoff.md](./12-session-handoff.md).
