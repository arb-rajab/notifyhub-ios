# Security

## JWT storage

The access token notifyhub issues is stored in the iOS Keychain
(`KeychainStore`, `kSecClassGenericPassword`), not `UserDefaults` -
`UserDefaults` is not encrypted at rest and is a poor fit for a bearer
credential. `kSecAttrAccessibleAfterFirstUnlock` is used (not
`...WhenUnlocked`) so a background push-triggered registration can still
read the token before the user has unlocked the device this boot.

On every launch, the stored token is revalidated against notifyhub's
`me` query rather than trusted blindly - notifyhub's JWTs are
short-lived by design (ADR-003 on notifyhub's side, 15 minutes default),
so a stale token is the expected case, not an edge case.

## APNs credentials - never in this repo or its CI, ever

This is the client-side half of notifyhub's own ADR-008 posture. This
app's `NotifyHubIOS.entitlements` declares the `aps-environment`
capability (required for the OS to allow push registration at all), but
no `.p8` signing key, Team ID, or real device token is ever present in
this repository, in `.github/workflows/ci.yml`, or in any CI secret.
Real push testing requires a physical device, a real Apple Developer
account, and the corresponding notifyhub backend configured with live
credentials outside any automated session - see
[08-risk.md](./08-risk.md) R-1 (mirrors notifyhub's R-8).

## Network transport

`Endpoints.swift` builds plain `http://`/`ws://` URLs by default,
matching notifyhub's own local-dev posture (no TLS termination in
`npm run dev`). **This is a development default, not a production
recommendation** - a real deployment must run notifyhub behind TLS and
point `NotifyHubHost` at an `https://`/`wss://`-capable host; `App
Transport Security` (ATS) will need a corresponding exception removed or
adjusted in `Info.plist` for a real, TLS-terminated deployment (not
present today because the default target has none).

## Deep-link payload trust

`DeepLinkCoordinator` treats the push payload's `channelSlug`/
`notificationId` as **navigation hints only**, not as authorization -
`ChannelDetailViewModel.loadInitial()` always re-fetches the channel and
its notifications from notifyhub over the authenticated GraphQL
connection rather than trusting anything in the payload as the truth.
A malformed or spoofed payload (not possible without already holding
valid APNs credentials for this app's bundle ID, but defense in depth
regardless) can at most navigate to a channel-slug screen that then
independently fails to load if the slug doesn't exist or the user isn't
authorized to see it.
