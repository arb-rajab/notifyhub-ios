# Backlog

Not committed to any timeline - ordered roughly by expected value for a
portfolio piece at this stage.

## Admin-only, not actionable by any session

- [x] Configure branch protection on `main` to require `build-and-test` as
      a required status check. Done, and extended further: the rule now
      also requires `Secret scan (gitleaks)` and `CodeQL (Swift)` (added
      once `.github/workflows/security.yml` existed). Fixed by the repo
      owner directly - see [08-risk.md](./08-risk.md) R-7.

## Near-term

- [ ] Reconnect/retry logic for `GraphQLSubscriptionClient` (exponential
      backoff on an unexpected close, matching the spirit of notifyhub's
      own `ApnsHttpClient` retry/backoff design on the server side) -
      [08-risk.md](./08-risk.md) R-3.
- [x] Surface a non-silent signal when push registration fails or the
      permission is denied: `PushStatus` (fed by `NotifyHubApp`,
      `AppSession`, `AppDelegate`) drives a dismissible `PushStatusBanner`
      in `RootView` - [08-risk.md](./08-risk.md) R-5. Still open: the
      banner doesn't re-check the permission on returning from Settings
      (it clears on next launch), and there's no persistent "registered"
      indicator - that would belong on the device-management screen below.
- [ ] A settings/device-management screen backed by the already-wired
      `myDeviceTokens` query and `revokeDeviceToken` mutation (both
      exist end-to-end on the client, just with no dedicated UI yet).
- [ ] SwiftUI view-level tests (snapshot or `ViewInspector`-style) for
      the views currently only covered indirectly through their
      `ViewModel`s - [08-risk.md](./08-risk.md) R-6.

## Medium-term

- [ ] Refresh tokens, if/when notifyhub's own ADR-003 tradeoff changes
      (this app's auth layer would need to change in lockstep -
      [08-risk.md](./08-risk.md) R-4).
- [ ] Rich push content (notification service/content extensions for
      images, custom UI) if notifyhub's `ApnsPushChannel` ever sends
      more than a plain alert payload.
- [ ] A local cache (e.g. lightweight `SwiftData`) for the channel list
      and recent notifications, so the app has something to show
      offline - explicitly out of this session's scope (see
      [01-brief.md](./01-brief.md) non-goals) but a natural next step if
      offline support is ever prioritized here the way it is in
      `lexicon-android`.

## Larger, deliberately deferred

- [ ] A local `graphql-transport-ws` echo server (reusing notifyhub's
      own `ws`/`graphql-ws` stack) to unit-test
      `GraphQLSubscriptionClient` itself against a real server, the same
      "real local server, not a mock" bar notifyhub's own
      `tests/unit/apnsHttpClient.test.ts` sets - needs a working local
      build/toolchain to develop against, which this session's sandbox
      doesn't have (see [05-testing.md](./05-testing.md),
      [06-ops.md](./06-ops.md)).
- [ ] Real device/live-APNs verification - permanently out of scope for
      any automated session, not merely deferred (see
      [07-decisions.md](./07-decisions.md) ADR-006,
      [08-risk.md](./08-risk.md) R-1).
