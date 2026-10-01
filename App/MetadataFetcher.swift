import LinkPresentation
import SwiftData

/// Replaces host-only placeholder titles with the real page title once the app is open.
@MainActor
enum MetadataFetcher {
    static func fillTitles(context: ModelContext) async {
        let pending = (try? context.fetch(FetchDescriptor<SavedItem>(
            predicate: #Predicate { $0.needsTitle == true && $0.openedAt == nil }))) ?? []
        // ponytail: sequential and capped at 10 per foreground; failures retry next time.
        for item in pending.prefix(10) {
            guard let url = item.url else { item.needsTitle = false; continue }
            let provider = LPMetadataProvider()
            provider.timeout = 8
            if let title = try? await provider.startFetchingMetadata(for: url).title, !title.isEmpty {
                item.title = String(title.prefix(200))
                item.needsTitle = false
            }
        }
        try? context.save()
    }
}
