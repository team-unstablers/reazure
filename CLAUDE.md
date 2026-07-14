# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**re;azure** is a keyboard-centric, *streaming-only* Mastodon client for iOS / iPadOS / visionOS / macOS. It recreates the UX of [Azurea](https://azurea.info) (tmyt's Windows/Windows Mobile Twitter client) on Apple platforms.

"Streaming-only" is a deliberate design constraint: the app subscribes to Mastodon's `/api/v1/streaming?stream=user` WebSocket for realtime home/notification updates and does **not** do offline caching (no SQLite/CoreData). There is no plan to add it. The home timeline is the streaming feed plus an occasional REST backfill; do not introduce a persistence layer without discussing it.

## Build, Run, Test

Xcode project (no `Package.swift` — SPM dependencies are wired into `reazure.xcodeproj`). Scheme: `reazure`.

```bash
# Build (pick an installed simulator; list them with `xcrun simctl list devices`)
xcodebuild -project reazure.xcodeproj -scheme reazure \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# Test — the unit target uses Swift Testing (`import Testing`, `@Test`), not XCTest
xcodebuild test -project reazure.xcodeproj -scheme reazure \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Single test: append the target/case, e.g.
#   -only-testing:reazureTests/reazureTests/example
```

There is **no** SwiftLint/SwiftFormat config — match the surrounding style, don't add a linter.

- **`BuildInfo.swift` is auto-generated and git-ignored — never edit it by hand.** A Run Script build phase (`cd $SRCROOT; perl genbuildinfo.pl`) regenerates it from git state (branch/commit/dirty/build date) on every build. `BuildInfoBase.swift` holds the struct definition.
- Deployment: iOS 17.6+. macOS is supported via "Designed for iPad" (Apple Silicon only), **not** Mac Catalyst (`SUPPORTS_MACCATALYST = NO`). Bundle id `pl.unstabler.reazure`.
- User-facing strings live in `reazure/Localizable.xcstrings` (this includes the `SHORTCUTKEY_DESCRIPTION_*` keys).

## Dependencies (SPM)

Alamofire (REST) · AlamofireImage (`CachedImageLoader`) · **Starscream** (WebSocket streaming) · **swift-collections** (`OrderedSet` for the timeline).

## Architecture

The app is built on Combine `ObservableObject`s injected as environment objects (not the newer `@Observable`/actor-isolation model). Async work hops back to the UI with `DispatchQueue.main.async` rather than `@MainActor` — keep this consistent when editing existing types.

### `SharedClient` — the central hub (`fediverse/SharedClient.swift`)

A singleton (`SharedClient.shared`) that owns nearly all app state and wears three hats:

1. **State container** — the active `MastodonClient`, `StreamingClient`, the `[TimelineType: TimelineModel]` map, current `Tab`, `streamingState`, unread count, and the `replyTo` subject. Setting `account` (via `didAccountChanged`) tears down and rebuilds the clients + timelines and reconnects streaming.
2. **`StreamingClientDelegate`** — receives decoded `update`/`notification` events and `prepend`s new `StatusModel`/`NotificationModel`s to the right timeline; plays sound / haptics on notifications. On disconnect it auto-reconnects after ~1s.
3. **`StatusModelActionPerformer`** — the concrete executor (`FediverseActionPerformer` in `fediverse/MastodonActionPerformer.swift`) for reblog/favourite/reply/delete/resolve/block/report, delegating to the active `FediverseClient`.

It also routes keyboard shortcuts: `handleShortcut` → `currentTimeline.handleShortcut`.

### Networking

- `MastodonClient` (`mastodon/MastodonAPI.swift`) — Alamofire REST wrapper. Endpoints are `MastodonEndpoint` values; OAuth is register-app → authorize (`urn:ietf:wg:oauth:2.0:oob`) → token.
- `StreamingClient` (`mastodon/StreamingClient.swift`) — Starscream WebSocket to `/api/v1/streaming`. State changes fire through its `delegate` (SharedClient), which drives the reconnect loop.

### Fediverse abstraction + Adaptor pattern (`fediverse/`)

The `fediverse/` layer is deliberately server-agnostic so backends beyond Mastodon can be added. `FediverseServer` is a `.mastodon` / `.misskey` enum, and **both are implemented**: `MastodonClient` and `MisskeyClient` each conform to `FediverseClient` (`fediverse/FediverseClient.swift`), hiding their differences (Misskey favourite ⇔ `⭐` reaction, boost ⇔ renote, report ⇔ user-level `users/report-abuse`) behind uniform method names. Adding an API call means touching both conformers.

Views and models never touch `Mastodon.Status` directly. They depend on **protocols** in `fediverse/models/adaptors.swift` (`StatusAdaptor`, `NotificationAdaptor`, `AccountAdaptor`, `AttachmentAdaptor`, …). `MastodonStatusAdaptor`/`MastodonNotificationAdaptor` (in `mastodon/objdef/Status.swift`) wrap the raw `Mastodon.*` decodable types (namespaced under the `Mastodon` enum in `mastodon/objdef/`).

**Optimistic UI via masking:** favourite/reblog/delete do not mutate the underlying adaptor. `StatusModelBase` (`fediverse/models/StatusModelBase.swift`) calls the performer, then replaces the status with a `MaskedStatusAdaptor` overlay (`status.mask(favourited:reblogged:deleted:blocked:)`) that reports the new flag while proxying everything else. When editing action logic, preserve this "call API, then swap in a masked copy" flow.

**Moderation (App Store guideline 1.2):** the post context menu offers **report** and **block** on other people's posts. Both are confirmed before they run (`PostRowPresentation` → `SetupContextMenuModifier`), and unlike the other actions they are **not** optimistic — a block masks rows only after the server accepts it, via a timeline-wide sweep (`SharedClient.applyBlock(accountId:)` → `TimelineModel.applyBlock`) that greys out every row the account authored *or* boosted. There is no persistent block list: the server stops delivering the account's posts, so only what is already on screen needs hiding.

### Models (`fediverse/models/`)

- `TimelineModel` — holds an `OrderedSet<StatusModel>`, a `focusState` (`{id, depth}`), and a `fetchFunction`. Streaming `prepend`s; `update()` REST-fetches and merges (sorted by id desc).
- `StatusModel` — wraps a `StatusAdaptor`, plus `parents: [StatusAdaptor]` (the lazily-resolved reply chain) and `expandedDepth`. Identity/hashing is by `status.id`.

### Keyboard shortcuts — the core UX (`views/core/ShortcutHandler.swift`, `fediverse/models/TimelineModel+shortcuts.swift`)

Vim-style. `ShortcutHandler` is a `UIViewControllerRepresentable` whose view controller becomes first responder and registers `UIKeyCommand`s (this was recently reworked from a SwiftUI approach to fix iPad shortcut handling — prefer the UIKit path). `ShortcutKey` cases:

- `h` / `l` — collapse / expand the focused thread depth
- `j` / `k` — focus next / previous status (arrow keys are aliased to these)
- `f` — toggle favourite · `t` — toggle reblog (boost) · `r` — reply
- `u` — toggle the post-composer focus

Depth (`focusState.depth`) lets `j`/`k` step through an expanded reply chain within a single row before moving to the next status.

### Views & Theming (`views/`, `theme/`)

`AppRootView` is a `NavigationStack` → `TabView` (system tab bar hidden) with a custom `Navbar`, optional `ExtKeypad`, the composer `PostArea`, and an invisible `ShortcutHandler`. Timeline rows render HTML content through `ActivityPubMarkupText` / `PostItem` / `CompactPostItem`.

Theming is via `AppTheme` (id + light/dark `AppPalette`) registered in `AppTheme.registry` (`default`, `AzureaSakura`), read from the SwiftUI environment as `\.appTheme` / `\.palette`. Add colors to `AppPalette` and implement them in **both** light and dark for **every** theme.

### Persistence

Only two things persist, both in `UserDefaults`: `AccountManager` serializes `[Account]` as JSON under the key `"accounts"`; `PreferencesManager.shared` holds settings.

## Conventions

- Comments and commit messages are professional/business tone even though the working code is peppered with candid `FIXME`/`TODO`/`HACK` notes (some in Korean). Follow the existing commit convention; do not add yourself as a Co-author.
- `fedi_id_t` is the `String` typealias used for fediverse object ids.
