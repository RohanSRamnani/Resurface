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
        List {
            header(ready: ready).bareRow(top: 12, bottom: 12)
            if ready.isEmpty {
                EmptyState(symbol: snoozed.isEmpty ? "tray" : "checkmark.circle",
                           title: snoozed.isEmpty ? "Nothing waiting" : "All caught up",
                           message: snoozed.isEmpty
                               ? "In any app, tap Share, then Resurface. It'll come back when you're free."
                               : "Your snoozed things will be back soon.")
                    .bareRow()
            }
            if let first = ready.first {
                actions(UpNextCard(item: first), item: first).bareRow(bottom: 10)
            }
            if ready.count > 1 {
                Caption("Then").bareRow(top: 14)
                ForEach(ready.dropFirst()) { item in
                    actions(ItemRow(item: item), item: item).bareRow()
                }
            }
            if !snoozed.isEmpty {
                Caption("Snoozed").bareRow(top: 18)
                ForEach(snoozed) { item in
                    ItemRow(item: item, subtitle: "Back \(item.snoozedUntil?.formatted(.relative(presentation: .named)) ?? "soon")")
                        .opacity(0.55)
                        .onTapGesture { router.open(item, context: context, openURL: openURL) }
                        .swipeActions {
                            Button { item.snoozedUntil = nil; context.commit() } label: { Label("Unsnooze", systemImage: "sun.max") }.tint(.orange)
                        }
                        .bareRow()
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .animation(.snappy, value: pending.map(\.id))
        .sensoryFeedback(.success, trigger: addedCount)
        .confirmationDialog("Snooze until", isPresented: Binding(get: { snoozing != nil }, set: { if !$0 { snoozing = nil } }),
                            titleVisibility: .visible, presenting: snoozing) { item in
            ForEach(SnoozeOption.allCases, id: \.label) { option in
                Button(option.label) { item.snoozedUntil = option.date(); context.commit() }
            }
        }
    }

    private func header(ready: [SavedItem]) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(ready.count)")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Caption(ready.first.map { "Waiting · oldest \($0.savedAt.formatted(.relative(presentation: .named)))" } ?? "Waiting")
            }
            Spacer()
            PasteButton(payloadType: String.self) { strings in
                guard let text = strings.first else { return }
                Task { @MainActor in
                    if let url = Incoming.firstURL(in: text) { context.saveLink(url, title: text) } else { context.saveNote(text) }
                    addedCount += 1
                }
            }
            .labelStyle(.iconOnly)
            .buttonBorderShape(.circle)
            .tint(Theme.cardLight)
            .padding(.bottom, 6)
        }
    }

    private func actions(_ view: some View, item: SavedItem) -> some View {
        view
            .onTapGesture { router.open(item, context: context, openURL: openURL) }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { context.remove(item) } label: { Label("Delete", systemImage: "trash") }
                Button { snoozing = item } label: { Label("Snooze", systemImage: "moon.zzz.fill") }.tint(.indigo)
            }
            .swipeActions(edge: .leading) {
                Button { item.openedAt = .now; context.commit() } label: { Label("Done", systemImage: "checkmark") }.tint(Theme.on)
            }
    }
}
