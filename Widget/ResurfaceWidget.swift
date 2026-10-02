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
        QueueEntry(date: .now, count: 4, rows: [
            .init(id: UUID(), title: "How to Do Great Work", source: .web),
            .init(id: UUID(), title: "15-minute crispy gnocchi, one pan", source: .tiktok),
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
        .fontDesign(.rounded)
        .containerBackground(for: .widget) {
            ZStack {
                Theme.background
                RadialGradient(colors: [.white.opacity(0.10), .clear], center: .topLeading, startRadius: 0, endRadius: 180)
            }
        }
    }

    private func link(_ row: QueueEntry.Row) -> URL { URL(string: "resurface://open/\(row.id.uuidString)")! }

    private var count: some View {
        Text("\(entry.count)").font(.system(size: 44, weight: .bold)).foregroundStyle(.white)
    }

    private func caption(_ text: String) -> some View {
        Text(text.uppercased()).font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(Theme.textSecondary)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let first = entry.rows.first {
                count
                caption("Waiting")
                Spacer(minLength: 6)
                Text(first.title).font(.footnote.weight(.medium)).foregroundStyle(.white).lineLimit(3)
            } else {
                Image(systemName: "checkmark.circle.fill").font(.largeTitle).foregroundStyle(Theme.on)
                Spacer(minLength: 6)
                Text("All caught up").font(.footnote.weight(.semibold)).foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(entry.rows.first.map(link))
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                count
                caption(entry.count == 0 ? "All clear" : "Waiting")
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(entry.rows.prefix(2)) { row in
                    Link(destination: link(row)) {
                        HStack(spacing: 10) {
                            Image(systemName: row.source.symbol)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(row.source.color)
                                .frame(width: 26, height: 26)
                                .background(row.source.color.opacity(0.16), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            Text(row.title).font(.footnote.weight(.medium)).foregroundStyle(.white).lineLimit(2)
                        }
                    }
                }
                if entry.rows.isEmpty {
                    Text("Share anything to Resurface and it'll wait here.").font(.footnote).foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var lockScreen: some View {
        VStack(alignment: .leading) {
            Label("\(entry.count) waiting", systemImage: "arrow.up.circle").font(.headline)
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
