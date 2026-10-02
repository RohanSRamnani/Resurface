import SwiftData
import SwiftUI

@main
struct ResurfaceApp: App {
    private let container: ModelContainer
    @State private var settings: AppSettings
    @State private var router = Router()

    init() {
        #if DEBUG
        DemoData.prepare()
        #endif
        let container = Store.makeContainer()
        #if DEBUG
        DemoData.seed(container)
        #endif
        self.container = container
        let settings = AppSettings(context: container.mainContext)
        _settings = State(initialValue: settings)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(router)
                .tint(Theme.accent)
                .fontDesign(.rounded)
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}

/// Nudge settings, persisted to the shared container on every change and re-planned immediately.
@MainActor @Observable
final class AppSettings {
    var value: NudgeSettings {
        didSet {
            guard value != oldValue else { return }
            value.save()
            NudgeScheduler.reschedule(context: context)
        }
    }
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        value = .load()
    }
}

/// Opens saved things and tracks the sheet shown for screenshots and notes.
@MainActor @Observable
final class Router {
    var presented: SavedItem?

    func open(_ item: SavedItem, context: ModelContext, openURL: OpenURLAction) {
        if item.openedAt == nil { item.openedAt = .now }
        item.snoozedUntil = nil
        switch item.kind {
        case .link:
            if let url = item.url { openURL(url) }
        case .image, .text:
            presented = item
        }
        context.commit()
    }
}
