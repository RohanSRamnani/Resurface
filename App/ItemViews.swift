import SwiftUI

struct ItemRow: View {
    let item: SavedItem
    var subtitle: String?

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.body).lineLimit(2)
                Text(subtitle ?? "\(item.source.displayName) · \(item.savedAt.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated)))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }

    @ViewBuilder private var thumbnail: some View {
        if let name = item.imageFilename, let image = ImageStore.image(named: name, thumbnail: true) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            ZStack {
                Rectangle().fill(item.source.color.gradient)
                Image(systemName: item.source.symbol).font(.title3).foregroundStyle(.white)
            }
        }
    }
}

/// Full view for things that aren't links: screenshots and notes.
struct ItemSheet: View {
    let item: SavedItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let name = item.imageFilename, let image = ImageStore.image(named: name) {
                    Image(uiImage: image).resizable().scaledToFit().padding()
                } else {
                    ScrollView { Text(item.text ?? item.title).textSelection(.enabled).padding() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle(item.source.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 44)).foregroundStyle(Theme.accent)
            Text(title).font(.title3.weight(.semibold))
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}
