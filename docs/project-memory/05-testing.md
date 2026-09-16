# Testing

## What's covered

- **`DeepLinkCoordinatorTests`** - the genuine push -> deep-link
  integration test this app's brief calls for, at the layer that's
  actually exercisable without live APNs or a physical device: feeds the
  exact payload shape notifyhub's `ApnsPushChannel` sends through
  `DeepLinkCoordinator.handle(userInfo:)` (the same method every one of
  `AppDelegate`'s three push-delivery-state callbacks funnels into) and
  asserts the resulting `AppRoute`, including the "no notificationId"
  channel-level case, a malformed payload being ignored, and a second
  push overwriting an unconsumed route.
- **`NotificationPayloadTests`** - the payload parsing itself, in
  isolation.
- **`GraphQLClientTests`** - against a `URLProtocol` stub (no real
  network): request shape (method, `Content-Type`, JSON body with
  `query`/`variables`), the `Authorization: Bearer <token>` header when
  a token is set, and error mapping (`UNAUTHENTICATED` extension code,
  non-2xx HTTP status).
- **`AuthServiceTests`**, **`PushRegistrationServiceTests`** - verify
  each operation sends the exact variables shape notifyhub's resolvers
  expect (cross-referenced against notifyhub's own
  `src/graphql/typeDefs/{user,deviceToken}.ts` and its
  `tests/integration/deviceTokens.test.ts`).
- **`KeychainStoreTests`** - real Keychain save/overwrite/clear/miss,
  against the Simulator's real Keychain (not mocked).
- **`JSONCodingTests`** - notifyhub's `DateTime` scalar format
  (ISO-8601 with milliseconds), including the no-milliseconds fallback
  and a malformed-string failure case.

## What's not, and why

- **Real push delivery to a device.** Cannot be verified from CI or any
  automated session - no live APNs credentials exist anywhere in this
  repo's reach, by design (see [04-security.md](./04-security.md),
  [08-risk.md](./08-risk.md) R-1). `DeepLinkCoordinatorTests` is the
  accepted proof for the routing logic; the actual APNs wire delivery is
  notifyhub backend's own protocol-level responsibility (see
  notifyhub's `tests/unit/apnsHttpClient.test.ts`).
- **SwiftUI view snapshot/UI tests.** Not written this session - the
  views are thin enough (ViewModels hold all the logic that's actually
  worth testing) that the ROI didn't clear the bar versus the ViewModel
  and networking tests above. Tracked in
  [09-backlog.md](./09-backlog.md) if a future session wants them.
- **`GraphQLSubscriptionClient` itself.** Not unit-tested directly - it
  needs a real WebSocket server to test meaningfully (the same
  "real local server, not a mock" bar notifyhub's own
  `apnsHttpClient.test.ts` sets), and this sandbox can't run the
  Simulator this client would need to be exercised in end-to-end. A
  future session with a working local build could stand up a minimal
  local `graphql-transport-ws` echo server (Node's `ws` + `graphql-ws`,
  same libraries notifyhub already uses) and drive this client against
  it the way notifyhub's own `subscription.test.ts` drives its server
  side.

## Running tests

**This sandbox has no Xcode or Swift toolchain at all** (Linux
container, no macOS) - nothing under `Sources/` or `Tests/` has been
locally compiled or run at any point this session. `.github/workflows/
ci.yml`'s `macos-14` job (`xcodegen generate` -> `xcodebuild build` ->
`xcodebuild test` against a dynamically-selected available iPhone
Simulator) is the **first and only** place any of this has actually
built. Trust that job's result, not this document's confidence, for
whether the code compiles - see [06-ops.md](./06-ops.md).
