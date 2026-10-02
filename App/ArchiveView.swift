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
        List {
            VStack(spacing: 14) {
                PageTitle("Archive")
                if !archived.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Theme.textSecondary)
                        TextField("Search archive", text: $search).foregroundStyle(.white)
                    }
                    .padding(12)
                    .glassCard(radius: 14)
                }
            }
            .bareRow(top: 12, bottom: 8)
            if archived.isEmpty {
                EmptyState(symbol: "archivebox", title: "Nothing here yet",
                           message: "Things you open from the queue land here, grouped by where they came from.")
                    .bareRow()
            }
            ForEach(Source.allCases.filter { groups[$0] != nil }, id: \.self) { source in
                HStack(spacing: 6) {
                    Image(systemName: source.symbol).font(.caption).foregroundStyle(source.color)
                    Caption("\(source.displayName) · \(groups[source]?.count ?? 0)")
                }
                .bareRow(top: 16)
                ForEach(groups[source] ?? []) { item in
                    ItemRow(item: item, subtitle: "Opened \(item.openedAt?.formatted(.relative(presentation: .named)) ?? "")")
                        .onTapGesture { router.open(item, context: context, openURL: openURL) }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { context.remove(item) } label: { Label("Delete", systemImage: "trash") }
                            Button { item.openedAt = nil; context.commit() } label: { Label("Back to queue", systemImage: "tray.and.arrow.up") }.tint(.indigo)
                        }
                        .bareRow()
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .background(Theme.background)
    }
}
