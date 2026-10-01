import SwiftData
import SwiftUI
import WidgetKit

struct QueueEntry: TimelineEntry {
    struct Row: Identifiable {
        let id: UUID
        let title: String
        let source: Source
    }
    let date: Date
    let count: Int
    let rows: [Row]
}

struct QueueProvider: TimelineProvider {
    func placeholder(in context: Context) -> QueueEntry {
        QueueEntry(date: .now, count: 3, rows: [
            .init(id: UUID(), title: "How to Do Great Work", source: .web),
            .init(id: UUID(), title: "The 5-minute pasta", source: .tiktok),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (QueueEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QueueEntry>) -> Void) {
        // Snoozed items reappear on their own, so refresh periodically as well as on app changes.
        completion(Timeline(entries: [load()], policy: .after(.now.addingTimeInterval(30 * 60))))
    }

    private func load() -> QueueEntry {
        let items = ModelContext(Store.makeContainer()).readyItems()
        return QueueEntry(date: .now, count: items.count,
                          rows: items.prefix(3).map { .init(id: $0.id, title: $0.title, source: $0.source) })
    }
}

struct WidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QueueEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular: lockScreen
            case .systemMedium: medium
            default: small
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func link(_ row: QueueEntry.Row?) -> URL { URL(string: "resurface://open/\(row?.id.uuidString ?? "")")! }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let first = entry.rows.first {
                Text("\(entry.count)").font(.system(size: 44, weight: .bold, design: .rounded)).foregroundStyle(Theme.accent)
                Text("waiting").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer(minLength: 2)
                Text(first.title).font(.footnote).lineLimit(3)
            } else {
                Image(systemName: "checkmark.circle.fill").font(.largeTitle).foregroundStyle(.green)
                Text("All caught up").font(.footnote.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(entry.rows.first.map(link))
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading) {
                Text("\(entry.count)").font(.system(size: 44, weight: .bold, design: .rounded)).foregroundStyle(Theme.accent)
                Text(entry.count == 0 ? "all caught up" : "waiting").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(entry.rows.prefix(2)) { row in
                    Link(destination: link(row)) {
                        HStack(spacing: 8) {
                            Image(systemName: row.source.symbol).foregroundStyle(row.source.color).frame(width: 18)
                            Text(row.title).font(.footnote).lineLimit(2).foregroundStyle(.primary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var lockScreen: some View {
        VStack(alignment: .leading) {
            Label("\(entry.count) waiting", systemImage: "tray.full").font(.headline)
            Text(entry.rows.first?.title ?? "All caught up").font(.caption).lineLimit(2)
        }
        .widgetURL(entry.rows.first.map(link))
    }
}

struct ResurfaceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ResurfaceQueue", provider: QueueProvider()) { entry in
            WidgetView(entry: entry)
        }
        .configurationDisplayName("Your queue")
        .description("What you saved and still want to get to.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

@main
struct ResurfaceWidgetBundle: WidgetBundle {
    var body: some Widget { ResurfaceWidget() }
}
