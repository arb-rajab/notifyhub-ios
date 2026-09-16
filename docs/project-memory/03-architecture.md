# Architecture

## Project layout

```
project.yml                            - XcodeGen spec; NotifyHubIOS.xcodeproj is generated, never committed
Sources/NotifyHubIOS/
  App/
    NotifyHubApp.swift                 - @main entry point, wires AppDelegate <-> AppSession, requests push auth
    AppDelegate.swift                  - UIApplicationDelegate + UNUserNotificationCenterDelegate
    AppSession.swift                   - composition root: owns clients/repositories, auth state
  Networking/
    Endpoints.swift                    - host configuration (Info.plist NotifyHubHost key)
    GraphQLClient.swift                - HTTP POST /graphql client
    GraphQLSubscriptionClient.swift    - graphql-transport-ws client over URLSessionWebSocketTask
    GraphQLError.swift, JSONCoding.swift
  Auth/
    AuthService.swift                  - register/login/me
    KeychainStore.swift                - JWT persistence
  Push/
    PushRegistrationService.swift      - registerDeviceToken/rotateDeviceToken/revokeDeviceToken
    NotificationPayload.swift          - the APNs payload's custom-key contract
    DeepLinkCoordinator.swift          - payload -> AppRoute, held until a view consumes it
  Models/                              - Codable types mirroring notifyhub's GraphQL schema
  Repositories/                        - ChannelRepository, NotificationRepository (queries/mutations/subscriptions)
  ViewModels/                          - ChannelListViewModel, ChannelDetailViewModel
  Views/                               - SwiftUI views
  Resources/                           - Info.plist, entitlements
Tests/NotifyHubIOSTests/               - XCTest suite (see 05-testing.md)
```

## Composition root

`AppSession` (a `@MainActor` `ObservableObject`) is the single place that
constructs the GraphQL HTTP client, the Keychain store, and every
repository/service built on them, and is injected into the SwiftUI
environment once from `NotifyHubApp`. Views never construct networking
objects themselves - they receive repositories (via `AppSession`) or a
fully-built `ViewModel` from their parent.

`DeepLinkCoordinator` is injected into the environment **separately**
from `AppSession`, even though `AppSession` owns an instance of it -
nested `ObservableObject`s don't propagate `objectWillChange`
notifications through a parent automatically in SwiftUI, so `RootView`
needs its own direct `@EnvironmentObject` subscription to actually
re-render when a push arrives. See `NotifyHubApp.body` for exactly where
this is wired, and don't remove that second `.environmentObject(...)`
call as a "duplicate."

## Networking - deliberately hand-rolled, not Apollo iOS

Both the GraphQL HTTP client and the subscription (WebSocket) client are
built directly on `URLSession`/`URLSessionWebSocketTask` rather than a
GraphQL client library. notifyhub's schema is small and stable enough
(ADR-001 on notifyhub's side: one schema, no REST) that a generated
client's codegen step and dependency weight isn't worth it for this
app's scope. See ADR-002 in [07-decisions.md](./07-decisions.md).

## Push architecture

`AppDelegate` is the single place that talks to `UIApplication`/
`UNUserNotificationCenter` directly. It:

1. Registers for remote notifications (via `NotifyHubApp` requesting
   authorization, then `UIApplication.registerForRemoteNotifications()`).
2. On `didRegisterForRemoteNotificationsWithDeviceToken`, converts the
   token to hex and calls `PushRegistrationService.rotate`, which falls
   back to a plain `register` when there's no previously-known token.
3. Routes every path that can deliver a push tap - foreground
   (`willPresent` completion is `.banner/.sound/.list`, deep-link on
   tap), background/killed via `didReceive response`, and a killed-state
   *cold launch* via `didFinishLaunchingWithOptions[.remoteNotification]`
   - into the same `DeepLinkCoordinator.handle(userInfo:)`. This is the
   one place the payload's `channelSlug`/`notificationId` custom keys
   are parsed; nothing else in the app touches raw `userInfo`.

`DeepLinkCoordinator` holds the most recently resolved `AppRoute` until
`RootView` is in a state to act on it (signed in) and consumes it,
pushing it onto the `NavigationStack` path. A push that arrives before
sign-in (a killed-state cold launch with no valid session yet) is held
until sign-in completes rather than dropped.

## Real-time subscription lifecycle

`NotificationRepository.subscribeToChannel` returns an
`AsyncThrowingStream<NotificationItem, Error>` backed by a per-call
`GraphQLSubscriptionClient` connection. `ChannelDetailViewModel` opens
this in `startLiveUpdates()` (called from the view's `.task`) and tears
it down in `stopLiveUpdates()` (called from `.onDisappear`) - the
subscription's lifetime is tied to the view's lifetime, not the app's,
matching how a user would expect "live while I'm looking at this
channel" to behave.
