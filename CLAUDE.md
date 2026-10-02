# Resurface

iOS app: save links/screenshots/text from any app via the share sheet, get nudged to read them when you're free. Local-only, no accounts.

## Commands
- `xcodegen generate` after editing `project.yml` or adding/removing files. `Resurface.xcodeproj` is generated, don't hand-edit.
- Test: `xcodebuild -project Resurface.xcodeproj -scheme Resurface -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test`
- Debug launch args (DEBUG only): `-resetData -skipOnboarding -seedDemo -tab N -onboardingPage N`

## Layout
- `Shared/` compiled into app + share extension + widget: SwiftData model, store, nudge planning, share intake (`ShareIngest`).
- `App/` SwiftUI app. `ShareExtension/` thin UIKit shell around `ShareIngest`. `Widget/` WidgetKit. `Tests/` unit tests.
- Data: one SwiftData store in App Group `group.com.rohan.resurface`; falls back to Application Support if the group isn't provisioned.

## Gotchas
- Share extension writes from another process: `RootView` bumps `.id(refresh)` on foreground so `@Query` re-fetches. Keep tab selection above that `.id` or it resets.
- Use `NSItemProvider.loadObject`, not `loadItem`: `loadItem` returns different types per sender and silently dropped URLs/text in tests.
- Nudges are local notifications planned 14 days ahead and rebuilt on every change; nothing is scheduled when the queue is empty.
- Bundle ids and App Group need the team set in `project.yml` (`DEVELOPMENT_TEAM`) to run on a real device.
- Not yet verified by hand: the real iOS share sheet, adding the widget, notification delivery. Unit tests and simulator screenshots cover the rest.

# Brain

The `brain/` directory is an Obsidian vault — persistent memory across sessions.

- **Read first.** Read brain files relevant to your task before acting.
- **Write** after mistakes, corrections, or notable codebase learnings.
- **Structure:** One topic per file. Directories with `[[wikilink]]` indexes — no inlined content.
- **Maintain:** Delete outdated notes and stale artifacts.
