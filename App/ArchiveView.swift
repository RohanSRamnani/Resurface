import SwiftData
import SwiftUI

struct ArchiveView: View {
    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router
    @Environment(\.openURL) private var openURL
    @Query(filter: #Predicate<SavedItem> { $0.openedAt != nil }, sort: \.openedAt, order: .reverse)
    private var archived: [SavedItem]
    @State private var search = ""

    var body: some View {
        let shown = search.isEmpty ? archived : archived.filter { $0.title.localizedCaseInsensitiveContains(search) }
        let groups = Dictionary(grouping: shown, by: \.source)
        NavigationStack {
            List {
                if archived.isEmpty {
                    EmptyState(symbol: "archivebox", title: "Nothing here yet",
                               message: "Things you open from the queue land here, grouped by where they came from.")
                }
                ForEach(Source.allCases.filter { groups[$0] != nil }, id: \.self) { source in
                    Section {
                        ForEach(groups[source] ?? []) { item in
                            ItemRow(item: item, subtitle: "Opened \(item.openedAt?.formatted(.relative(presentation: .named)) ?? "")")
                                .onTapGesture { router.open(item, context: context, openURL: openURL) }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { context.remove(item) } label: { Label("Delete", systemImage: "trash") }
                                    Button { item.openedAt = nil; context.commit() } label: { Label("Back to queue", systemImage: "tray.and.arrow.up") }.tint(Theme.accent)
                                }
                        }
                    } header: {
                        Label("\(source.displayName) · \(groups[source]?.count ?? 0)", systemImage: source.symbol)
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $search, prompt: "Search archive")
            .navigationTitle("Archive")
        }
    }
}
