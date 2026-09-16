# Release Notes

## v0.1.0 (this session) - initial build

- Native Swift/SwiftUI app scaffolded via XcodeGen (`project.yml`).
- Auth against notifyhub's JWT (register/login/`me`, Keychain-backed
  persistence).
- Channel browse (with search), create, subscribe/unsubscribe.
- Notification list per channel, plus live updates over notifyhub's
  `notificationReceived` GraphQL subscription while a channel's detail
  screen is open.
- APNs device-token registration/rotation wired to notifyhub's new
  `registerDeviceToken`/`rotateDeviceToken`/`revokeDeviceToken`
  mutations (added to notifyhub in the same session, see notifyhub's
  ADR-008).
- Push handling and deep-linking in all three app states (foreground,
  background, killed), routing on the payload's `channelSlug`/
  `notificationId` custom keys into the right channel/notification.
- XCTest suite covering the deep-link routing contract, networking
  request shapes, auth, push registration, Keychain persistence, and
  date decoding - see [05-testing.md](./05-testing.md) for what is and
  isn't covered and why.
- CI (`.github/workflows/ci.yml`, `macos-14`) is the first and only
  place any of this has actually been built - this development sandbox
  has no Xcode/Swift toolchain at all.

**Known, permanent limitation:** no real APNs delivery to a physical
device can be verified from this repo, this session, or its CI - see
[07-decisions.md](./07-decisions.md) ADR-006 and
[08-risk.md](./08-risk.md) R-1.
