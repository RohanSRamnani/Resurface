import SwiftUI

extension View {
    /// Strip List chrome so glass cards sit on the dark ground.
    func bareRow(top: CGFloat = 5, bottom: CGFloat = 5) -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: top, leading: 16, bottom: bottom, trailing: 16))
    }
}

/// Screenshot thumbnail, or the source glyph on a tinted tile.
struct SourceTile: View {
    let item: SavedItem
    var size: CGFloat = 48

    var body: some View {
        Group {
            if let name = item.imageFilename, let image = ImageStore.image(named: name, thumbnail: true) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    item.source.color.opacity(0.16)
                    Image(systemName: item.source.symbol)
                        .font(.system(size: size * 0.38, weight: .semibold))
                        .foregroundStyle(item.source.color)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ItemRow: View {
    let item: SavedItem
    var subtitle: String?

    var body: some View {
        HStack(spacing: 14) {
            SourceTile(item: item)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.body.weight(.medium)).foregroundStyle(.white).lineLimit(2)
                Text(subtitle ?? "\(item.source.displayName) · \(item.savedAt.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated)))")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassCard()
        .contentShape(Rectangle())
    }
}

/// The oldest thing in the queue, surfaced: the app's signature card.
struct UpNextCard: View {
    let item: SavedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Caption("Up next")
                Spacer()
                Label(item.source.displayName, systemImage: item.source.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.source.color)
            }
            if let name = item.imageFilename, let image = ImageStore.image(named: name) {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(height: 200).frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            Text(item.title).font(.title2.weight(.bold)).foregroundStyle(.white).lineLimit(3)
            HStack {
                Text("Saved \(item.savedAt.formatted(.relative(presentation: .named)))")
                    .font(.footnote).foregroundStyle(Theme.textSecondary)
                Spacer()
                Label("Open", systemImage: "arrow.up.right")
                    .labelStyle(TrailingIcon())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(.white, in: Capsule())
            }
        }
        .padding(20)
        .glassCard(radius: Theme.radiusLarge, glow: true)
        .contentShape(Rectangle())
    }
}

private struct TrailingIcon: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) { configuration.title; configuration.icon }
    }
}

/// Full view for things that aren't links: screenshots and notes.
struct ItemSheet: View {
    let item: SavedItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Caption(item.source.displayName)
                Spacer()
                Button("Done") { dismiss() }.font(.body.weight(.semibold)).foregroundStyle(.white)
            }
            .padding(20)
            if let name = item.imageFilename, let image = ImageStore.image(named: name) {
                Image(uiImage: image).resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                    .padding(.horizontal, 20)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    Text(item.text ?? item.title).font(.title3).foregroundStyle(.white)
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(20)
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 40, weight: .semibold)).foregroundStyle(.white)
            Text(title).font(.title3.weight(.bold)).foregroundStyle(.white)
            Text(message).font(.subheadline).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40).padding(.horizontal, 24)
        .glassCard(radius: Theme.radiusLarge, glow: true)
    }
}

/// Big rounded page title used in place of the system navigation title.
struct PageTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.largeTitle.weight(.bold)).foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
