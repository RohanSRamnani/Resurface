import ImageIO
import SwiftData
import UIKit
import UniformTypeIdentifiers
import WidgetKit

/// One SwiftData store in the App Group container, shared by the app, share extension and widget.
enum Store {
    static let appGroup = "group.com.rohan.resurface"

    static var directory: URL {
        let fm = FileManager.default
        // Falls back to Application Support when the App Group isn't provisioned (e.g. unsigned test runs).
        let base = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([SavedItem.self])
        let config = inMemory
            ? ModelConfiguration(isStoredInMemoryOnly: true)
            : ModelConfiguration(schema: schema, url: directory.appendingPathComponent("resurface.store"))
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Could not open store: \(error)")
        }
    }

    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }
}

extension ModelContext {
    /// Queue items that are not snoozed, oldest first.
    func readyItems(now: Date = .now) -> [SavedItem] {
        let pending = (try? fetch(FetchDescriptor<SavedItem>(
            predicate: #Predicate { $0.openedAt == nil },
            sortBy: [SortDescriptor(\.savedAt)]))) ?? []
        return pending.filter { $0.isReady(now: now) }
    }

    /// Persist, refresh the widget, and re-plan nudges. Call after any change.
    func commit() {
        try? save()
        WidgetCenter.shared.reloadAllTimelines()
        NudgeScheduler.reschedule(context: self)
    }

    @discardableResult
    func saveLink(_ url: URL, title: String? = nil) -> SavedItem {
        let key = url.absoluteString
        let existing = try? fetch(FetchDescriptor<SavedItem>(
            predicate: #Predicate { $0.urlString == key && $0.openedAt == nil })).first
        if let existing {
            existing.snoozedUntil = nil // saving again means "I want this now"
            commit()
            return existing
        }
        // Shared text often includes the link itself; keep only the words around it.
        let cleaned = (title ?? "").replacingOccurrences(of: key, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let host = (url.host ?? key).replacingOccurrences(of: "www.", with: "")
        let item = SavedItem(kind: .link, url: url, title: String((cleaned.isEmpty ? host : cleaned).prefix(200)),
                             source: .detect(url: url), needsTitle: cleaned.isEmpty)
        insert(item)
        commit()
        return item
    }

    @discardableResult
    func saveImage(data: Data) throws -> SavedItem {
        let name = try ImageStore.save(data: data)
        let item = SavedItem(kind: .image, title: "Screenshot", source: .screenshot, imageFilename: name)
        insert(item)
        commit()
        return item
    }

    @discardableResult
    func saveNote(_ text: String) -> SavedItem {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = SavedItem(kind: .text, title: String(trimmed.prefix(200)), text: trimmed, source: .note)
        insert(item)
        commit()
        return item
    }

    func remove(_ item: SavedItem) {
        if let name = item.imageFilename { ImageStore.delete(name) }
        delete(item)
        commit()
    }
}

/// Screenshots are stored as downsampled JPEGs (full + thumbnail) in the shared container.
enum ImageStore {
    struct Failure: Error {}

    static var directory: URL {
        let dir = Store.directory.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func save(data: Data) throws -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { throw Failure() }
        let name = UUID().uuidString + ".jpg"
        try write(source, maxPixel: 1600, to: directory.appendingPathComponent(name))
        try write(source, maxPixel: 300, to: directory.appendingPathComponent("thumb_" + name))
        return name
    }

    private static func write(_ source: CGImageSource, maxPixel: Int, to url: URL) throws {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw Failure() }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw Failure() }
    }

    static func image(named name: String, thumbnail: Bool = false) -> UIImage? {
        UIImage(contentsOfFile: directory.appendingPathComponent((thumbnail ? "thumb_" : "") + name).path)
    }

    static func delete(_ name: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("thumb_" + name))
    }
}
