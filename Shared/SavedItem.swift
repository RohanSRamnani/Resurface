import Foundation
import SwiftData

enum ItemKind: String {
    case link, image, text
}

@Model
final class SavedItem {
    var id: UUID
    var kindRaw: String
    var urlString: String?
    var title: String
    var text: String?
    var sourceRaw: String
    var imageFilename: String?
    var savedAt: Date
    var snoozedUntil: Date?
    /// Non-nil means archived: the thing was opened (or marked done) at this time.
    var openedAt: Date?
    /// True while `title` is just the host and the real page title hasn't been fetched yet.
    var needsTitle: Bool

    init(kind: ItemKind, url: URL? = nil, title: String, text: String? = nil, source: Source,
         imageFilename: String? = nil, savedAt: Date = .now, needsTitle: Bool = false) {
        id = UUID()
        kindRaw = kind.rawValue
        urlString = url?.absoluteString
        self.title = title
        self.text = text
        sourceRaw = source.rawValue
        self.imageFilename = imageFilename
        self.savedAt = savedAt
        self.needsTitle = needsTitle
    }

    var kind: ItemKind { ItemKind(rawValue: kindRaw) ?? .link }
    var source: Source { Source(rawValue: sourceRaw) ?? .web }
    var url: URL? { urlString.flatMap(URL.init(string:)) }
    var isArchived: Bool { openedAt != nil }

    /// In the queue and not snoozed.
    func isReady(now: Date = .now) -> Bool {
        openedAt == nil && (snoozedUntil.map { $0 <= now } ?? true)
    }
}
