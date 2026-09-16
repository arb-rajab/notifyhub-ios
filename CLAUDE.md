# CLAUDE.md — notes for future sessions on this repo

Repo-specific ways to avoid burning tokens re-discovering things this
session already worked out. Read this before re-exploring the codebase
from scratch.

## This sandbox cannot build, run, or test Swift at all — don't try

Unlike notifyhub (which has a real local Postgres and can actually run
`npm test`), this sandbox is a Linux container with **no Xcode, no
Swift toolchain, no `swift` or `xcodebuild` binary, nothing.** Don't run
`swift build`, `xcodebuild`, `xcodegen generate`, or anything else that
assumes a Swift compiler exists here - it will simply fail with "command
not found," and burning a turn trying variations of that command is
wasted. `.github/workflows/ci.yml`'s `macos-14` job is the **only**
place any of this has ever been compiled. If you need to know whether
the code actually builds, check that job's result - don't guess, and
don't claim it builds based on "I read it carefully."

## Trailing commas in Swift parameter/argument lists — avoid them

This session went through every file it wrote and stripped trailing
commas from multi-line function declarations and call argument lists
(kept them only in array/dictionary literals, where they've always been
safe). Newer Swift toolchains may well accept trailing commas there too,
but this session had no compiler available to confirm it, so it erred
conservative rather than gamble on syntax it couldn't check. If a future
session **can** actually compile (i.e. has real Xcode access), it's fine
to relax this - but verify by compiling, don't just assume the newer
grammar is in effect.

## The push payload contract lives in two repos — grep both before changing it

`Sources/NotifyHubIOS/Push/NotificationPayload.swift` (`channelSlug`,
`notificationId` as the two custom APNs payload keys) must stay in sync
with notifyhub's `src/services/push/apnsChannel.ts`'s `buildApnsPayload`.
Nothing enforces this automatically across the two repos - no shared
schema, no codegen, no CI check that fails if they drift. If you change
one, grep the other and change it too in the same PR pass (both repos
are normally checked out side by side in the same session, per this
portfolio's "coupled work stays coupled" pattern - see notifyhub-ios's
own `docs/project-memory/01-brief.md`).

## Why there's no `.xcodeproj` committed

`project.yml` (XcodeGen) generates it; `.gitignore` excludes it. Don't
hand-write or commit a `.xcodeproj` - see ADR-002 in
`docs/project-memory/07-decisions.md`. If you add a new source file,
add it under the right `sources:` path in `project.yml` if the path
pattern doesn't already glob it in (check the existing `Sources/
NotifyHubIOS` / `Tests/NotifyHubIOSTests` path entries first - they're
directory globs, so a new file in an existing directory needs no
`project.yml` change, only a new *directory* does).

## Where to look before adding a new GraphQL operation

Every existing operation lives in `Repositories/` (channels,
notifications) or a dedicated service (`AuthService`, `PushRegistration
Service`) - follow that pattern (a plain `struct` wrapping a
`GraphQLClient`, one method per operation, an inline nested `Response:
Decodable` type per method) rather than introducing a new abstraction.
Cross-check the exact field/argument names against notifyhub's
`src/graphql/typeDefs/*.ts` directly - there is no schema-introspection
tooling wired up here (deliberately - see ADR-003) to catch a
mismatched field name for you.

## Simulator vs. real device vs. CI, for push-related work specifically

- **This sandbox:** can't run anything Swift at all (see above).
- **CI (`macos-14` Simulator):** can build and run `DeepLinkCoordinator
  Tests` etc. against a Simulator, but the Simulator cannot receive a
  real Apple-delivered push - `xcrun simctl push` can inject a
  locally-crafted payload for manual testing, but that's not wired into
  this repo's CI and would need a real macOS session to use anyway.
- **A physical device with real credentials:** the only place real
  end-to-end push delivery can ever be verified - permanently outside
  what any automated session (this one included) can do. See
  `docs/project-memory/08-risk.md` R-1. Don't try to "fix" this; it's
  not a gap in this session's work, it's a standing constraint.
