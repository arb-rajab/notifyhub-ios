# Requirements

## Functional

- **Auth.** Register and sign in against notifyhub's `register`/`login`
  mutations (ADR-003 on notifyhub's side: short-lived JWTs, no
  server-side session). The token is persisted in the Keychain and
  restored (and revalidated against `me`) on next launch.
- **Channel browse/subscribe.** List channels (with search), view a
  channel's detail, subscribe/unsubscribe, create a new channel.
- **Notification list + live updates.** View a channel's recent
  notifications (`notifications` query) and receive new ones in real
  time while the channel detail screen is open, over notifyhub's
  `notificationReceived` GraphQL subscription.
- **Device push registration.** Register the device's APNs token with
  notifyhub on launch (once signed in) and on every APNs token
  rotation, via `registerDeviceToken`/`rotateDeviceToken`.
- **Push delivery + deep-linking**, in all three app states:
  - **Foreground** - banner shown via `UNUserNotificationCenterDelegate`;
    tapping it deep-links the same as any other state.
  - **Background** - system notification; tapping deep-links into the
    channel/notification.
  - **Killed** - cold launch from a notification tap deep-links into the
    channel/notification once the app finishes launching.
  - The deep-link target is resolved from the payload's `channelSlug`
    (and, for a specific notification, `notificationId`) custom keys -
    the exact contract notifyhub's `ApnsPushChannel` sends.

## Non-functional

- **No live APNs credentials, ever, in this repo or its CI.** Same
  posture as notifyhub's own ADR-008 and pulsewatch-mobile's equivalent
  gap - this is permanent, not a TODO.
- **Buildable and testable only in CI** (a macOS GitHub Actions runner) -
  this development sandbox has no Xcode or Swift toolchain at all, so
  nothing here has been locally compiled; see
  [06-ops.md](./06-ops.md).
- **iOS 16+** deployment target (the app uses `NavigationStack` and
  other iOS 16 SwiftUI APIs throughout).

## Out of scope for this session

- Push notification **content** customization beyond title/body/sound
  (no rich media attachments, no notification categories/actions).
- Multi-device token management UI (the `myDeviceTokens` query exists on
  both sides of the contract but has no dedicated settings screen yet -
  see [09-backlog.md](./09-backlog.md)).
- Admin-role features (notifyhub's `Role.ADMIN` isn't surfaced in this
  app at all).
