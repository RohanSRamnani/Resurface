# Resurface design

**Problem:** people save things (tweets, TikToks, screenshots) and never return. Saving is solved; coming back isn't.

**Decisions**
- Native iOS, SwiftUI + SwiftData, iOS 17+. Local only, no login, no backend (test "do people come back" before sync).
- Save via one share extension: links, screenshots (screenshot preview → Share), text. Zero decisions at save time.
- Nudge: free windows (default morning + evening) or a single daily digest. One notification per window, never per item. Plus a home screen widget as the standing reminder. User picks in 3-screen onboarding with good defaults.
- Lifecycle: queue that empties. Opening archives (not deletes); archive groups by source automatically. Swipe to snooze.
- Skipped for v1: auto-detecting screenshots (needs photo permission), tags/folders/notes, sync, Android.

**Open questions:** will people pay? Test with friends first. Possible paid tier: sync, smarter nudge timing, summaries.
