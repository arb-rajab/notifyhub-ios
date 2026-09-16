# Architecture Decision Records

Format: Context → Decision → Consequences, numbered chronologically -
matching notifyhub's own ADR log format and conventions.

---

## ADR-001: Native Swift/SwiftUI, not a cross-platform framework

**Context.** The portfolio's mobile-coverage plan deliberately uses
cross-platform frameworks (React Native, Flutter, etc.) almost
everywhere, with exactly two repos designated native:
`lexicon-android` (native Android/Kotlin) and this repo.

**Decision.** Swift + SwiftUI, targeting iOS 16+, with no
cross-platform framework involved.

**Consequences.** This repo can genuinely demonstrate iOS-native APIs
end to end - `UIApplicationDelegate`/`UNUserNotificationCenterDelegate`
for push, Keychain Services for secure storage, `URLSessionWebSocketTask`
for the real-time transport - none of which a cross-platform push
plugin would exercise the same way. The cost is no code sharing with
any Android counterpart; accepted, since that's the deliberate portfolio
pattern this repo exists to fill.

---

## ADR-002: XcodeGen (`project.yml`), not a committed `.xcodeproj`

**Context.** An Xcode project needs a `.xcodeproj` (`.pbxproj`) to
build. That format is a sprawling, easy-to-corrupt property list that
merges badly and is effectively impossible to hand-author correctly
without Xcode itself to validate it - and this development sandbox has
no Xcode or Swift toolchain at all (a Linux container), so a
hand-written `.pbxproj` here would have gone completely unverified
until CI's first run.

**Decision.** `project.yml` (XcodeGen's spec format) is the committed
source of truth; `.xcodeproj` is generated (`xcodegen generate`) and
`.gitignore`d. CI runs the same generation step before building.

**Consequences.** The project structure is legible, diffable, and
mergeable as plain YAML instead of an opaque generated format, and
every target/scheme/build-setting change is a `project.yml` edit,
reviewable the same way any other source change is. The cost is one
extra CI/local-build step (`xcodegen generate`) before anything else
can run - accepted, it's a single well-documented command
([06-ops.md](./06-ops.md)).

---

## ADR-003: A hand-rolled GraphQL/WebSocket client on `URLSession`, not Apollo iOS

**Context.** notifyhub's entire API surface is one small, stable GraphQL
schema (notifyhub's own ADR-001: GraphQL only, no REST) plus one
subscription. A generated client (Apollo iOS, being the standard choice)
brings codegen tooling, a `.graphql` schema-download step, and a
non-trivial dependency footprint - proportionate for a large, evolving
schema, not for this app's scope.

**Decision.** `GraphQLClient` (HTTP, `URLSession`) and
`GraphQLSubscriptionClient` (`graphql-transport-ws` over
`URLSessionWebSocketTask`) are both hand-written against exactly the
operations this app uses, with `Codable` models mirroring notifyhub's
schema types directly (`Models/`).

**Consequences.** Zero external dependencies for networking, and every
request this app can send is visible as a plain Swift string/dictionary
literal in the repository/service that sends it - easy to
cross-reference directly against notifyhub's own
`src/graphql/typeDefs/*.ts` and resolver code. The cost: no compile-time
guarantee that a query string matches the server schema (a generated
client would catch a typo'd field at build time; this approach catches
it at runtime, covered instead by the request-shape tests in
[05-testing.md](./05-testing.md)). Revisit if/when notifyhub's schema
grows enough that this tradeoff flips.

---

## ADR-004: `@UIApplicationDelegateAdaptor`, not a SwiftUI-only lifecycle

**Context.** Registering for remote notifications, receiving the raw
APNs device token, and handling a notification tap in every app state
are all UIKit-level `UIApplicationDelegate`/
`UNUserNotificationCenterDelegate` callbacks with no SwiftUI-only
equivalent as of this app's iOS 16 deployment target.

**Decision.** `NotifyHubApp` uses
`@UIApplicationDelegateAdaptor(AppDelegate.self)`, and `AppDelegate`
owns all push-lifecycle callbacks, calling into `DeepLinkCoordinator`
(injected once, right after the adaptor constructs it) rather than
duplicating payload-parsing logic itself.

**Consequences.** One `AppDelegate` instance lives for the app's
lifetime, giving push handling a stable, testable home
(`DeepLinkCoordinatorTests` exercises exactly the method every push
path calls into) without SwiftUI's view lifecycle getting involved in
UIKit-level callbacks.

---

## ADR-005: Keychain for the JWT, not `UserDefaults`

**Context.** notifyhub issues a bearer JWT (its own ADR-003) that this
app must persist across launches. `UserDefaults` is the path of least
resistance but stores plaintext, unencrypted values in a plist on disk.

**Decision.** `KeychainStore` wraps Keychain Services
(`kSecClassGenericPassword`) for the single secret this app has to
store. Not a general-purpose Keychain library - one type, one secret.

**Consequences.** The token is encrypted at rest by the OS. The stored
token is still re-validated against `me` on every launch rather than
trusted blindly (notifyhub's tokens expire in 15 minutes by default),
so Keychain persistence is a convenience (skip re-login) rather than a
source of truth about validity.

---

## ADR-006: Mock/protocol-level verification is the permanent proof standard here too

**Context.** This app's entire reason for existing is demonstrating
real APNs push, but real APNs delivery requires a physical device, a
real Apple Developer account, and notifyhub's own live credentials
(never present in notifyhub's repo or CI - notifyhub's ADR-008). No
automated session, this one included, can close that gap - not because
of a missing feature, but because doing so would require exactly the
kind of credential exposure ADR-008 exists to prevent.

**Decision.** The client-side proof of correctness for push handling is
`DeepLinkCoordinatorTests`: the exact payload shape notifyhub's
`ApnsPushChannel` sends, fed through the same routing method every one
of `AppDelegate`'s push-delivery-state callbacks calls into. This is
recorded as a **permanent** limitation (not a TODO) in
[08-risk.md](./08-risk.md) R-1, mirroring notifyhub's own R-8 and
pulsewatch-mobile's equivalent documented gap elsewhere in the
portfolio.

**Consequences.** This repo can never claim "verified working push
delivery" from within itself or from CI. Anyone needing that assurance
runs the app on a physical device with real credentials, outside any
automated session, by design.
