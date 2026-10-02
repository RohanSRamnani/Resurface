import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    /// Bumped on every foreground so @Query re-fetches rows the share extension wrote from another process.
    @State private var refresh = 0
    /// Lives here, not in MainTabs, so the refresh below doesn't reset it.
    @State private var tab = DebugArgs.int("-tab") ?? 0

    var body: some View {
        @Bindable var router = router
        Group {
            if settings.value.onboarded {
                MainTabs(tab: $tab).id(refresh)
            } else {
                OnboardingView()
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .sheet(item: $router.presented) { ItemSheet(item: $0) }
        .onOpenURL { url in
            // Widget taps arrive as resurface://open/<uuid>.
            guard url.host == "open", let id = UUID(uuidString: url.lastPathComponent) else { return }
            let item = try? context.fetch(FetchDescriptor<SavedItem>(predicate: #Predicate { $0.id == id })).first
            if let item { router.open(item, context: context, openURL: openURL) }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            refresh += 1
            NudgeScheduler.reschedule(context: context)
            Task { await MetadataFetcher.fillTitles(context: context) }
        }
    }
}

struct MainTabs: View {
    @Binding var tab: Int

    init(tab: Binding<Int>) {
        _tab = tab
        let bar = UITabBarAppearance()
        bar.configureWithOpaqueBackground()
        bar.backgroundColor = UIColor(Theme.background)
        bar.shadowColor = UIColor(Theme.border)
        UITabBar.appearance().standardAppearance = bar
        UITabBar.appearance().scrollEdgeAppearance = bar
    }

    var body: some View {
        TabView(selection: $tab) {
            QueueView().tabItem { Label("Queue", systemImage: "tray.full") }.tag(0)
            ArchiveView().tabItem { Label("Archive", systemImage: "archivebox") }.tag(1)
            SettingsView().tabItem { Label("Settings", systemImage: "slider.horizontal.3") }.tag(2)
        }
    }
}
