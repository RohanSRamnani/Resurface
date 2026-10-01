import SwiftData
import SwiftUI

struct QueueView: View {
    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router
    @Environment(\.openURL) private var openURL
    @Query(filter: #Predicate<SavedItem> { $0.openedAt == nil }, sort: \.savedAt)
    private var pending: [SavedItem]
    @State private var snoozing: SavedItem?
    @State private var addedCount = 0

    var body: some View {
        let now = Date.now
        let ready = pending.filter { $0.isReady(now: now) }
        let snoozed = pending.filter { !$0.isReady(now: now) }
        NavigationStack {
            List {
                if ready.isEmpty {
                    EmptyState(symbol: "checkmark.circle",
                               title: snoozed.isEmpty ? "Nothing waiting" : "All caught up",
                               message: snoozed.isEmpty
                                   ? "Share a link or screenshot to Resurface from any app and it'll show up here."
                                   : "Your snoozed items will be back soon.")
                }
                ForEach(ready) { item in
                    ItemRow(item: item)
                        .onTapGesture { router.open(item, context: context, openURL: openURL) }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { context.remove(item) } label: { Label("Delete", systemImage: "trash") }
                            Button { snoozing = item } label: { Label("Snooze", systemImage: "moon.zzz.fill") }.tint(.indigo)
                        }
                        .swipeActions(edge: .leading) {
                            Button { item.openedAt = .now; context.commit() } label: { Label("Done", systemImage: "checkmark") }.tint(.green)
                        }
                }
                if !snoozed.isEmpty {
                    Section("Snoozed") {
                        ForEach(snoozed) { item in
                            ItemRow(item: item, subtitle: "Back \(item.snoozedUntil?.formatted(.relative(presentation: .named)) ?? "soon")")
                                .opacity(0.6)
                                .onTapGesture { router.open(item, context: context, openURL: openURL) }
                                .swipeActions {
                                    Button { item.snoozedUntil = nil; context.commit() } label: { Label("Unsnooze", systemImage: "sun.max") }.tint(.orange)
                                }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(ready.isEmpty ? "Queue" : "\(ready.count) waiting")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    PasteButton(payloadType: String.self) { strings in
                        guard let text = strings.first else { return }
                        Task { @MainActor in
                            if let url = Incoming.firstURL(in: text) { context.saveLink(url, title: text) } else { context.saveNote(text) }
                            addedCount += 1
                        }
                    }
                    .labelStyle(.iconOnly)
                }
            }
            .sensoryFeedback(.success, trigger: addedCount)
            .confirmationDialog("Snooze", isPresented: Binding(get: { snoozing != nil }, set: { if !$0 { snoozing = nil } }),
                                titleVisibility: .visible, presenting: snoozing) { item in
                ForEach(SnoozeOption.allCases, id: \.label) { option in
                    Button(option.label) { item.snoozedUntil = option.date(); context.commit() }
                }
            }
        }
    }
}
