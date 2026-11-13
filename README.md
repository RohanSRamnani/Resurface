# Resurface

iOS app for the links you save and never read. Share anything into it from any
app, and it nudges you to read it when you actually have a gap. Local only, no
accounts, nothing leaves the phone.

## How it works

Three targets share one SwiftData store in an App Group:

- **App** is SwiftUI. A queue, an archive, settings, onboarding.
- **ShareExtension** is a thin UIKit shell around `ShareIngest`, the same intake
  code the app uses, so a save from the share sheet and a save from inside the
  app go through one path.
- **Widget** is WidgetKit, showing what is up next on the home screen.

`Shared/` holds everything all three need: the model, the store, share intake,
and nudge planning. Nudges are local notifications planned fourteen days ahead
and rebuilt from scratch on every change, so there is no scheduling state to go
stale. Nothing gets scheduled when the queue is empty.

The signature interaction is that the oldest thing in the queue rises into the
big "Up next" card. The longer you ignore something the more it is in your way.

## Running it

`Resurface.xcodeproj` is generated. Edit `project.yml`, then:

```bash
xcodegen generate
```

```bash
xcodebuild -project Resurface.xcodeproj -scheme Resurface -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

Debug launch arguments for jumping straight to a screen with demo data:
`-resetData -skipOnboarding -seedDemo -tab N -onboardingPage N`.

Running on a real device needs `DEVELOPMENT_TEAM` set in `project.yml`, since the
bundle ids and the App Group depend on it.

## Notes from building it

Use `NSItemProvider.loadObject`, not `loadItem`. `loadItem` hands back a
different type depending on which app shared to you, and it was silently
dropping URLs and text.

The share extension writes from a different process, so the app will not see new
items on its own. `RootView` bumps `.id(refresh)` when it comes to the
foreground to force `@Query` to re-fetch. Tab selection has to live above that
`.id` or switching back resets which tab you were on.

The store falls back to Application Support when the App Group is not
provisioned, which keeps the app running on a machine without the entitlement
instead of crashing on launch.
