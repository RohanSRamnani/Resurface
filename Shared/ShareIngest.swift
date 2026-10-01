import SwiftData
import UniformTypeIdentifiers

/// Turns whatever the iOS share sheet hands us into a saved item. Lives here (not in the extension)
/// so unit tests can feed it real NSItemProviders.
enum ShareIngest {
    /// Returns a short "what was saved" message, or nil when there was nothing usable.
    /// Priority: web link, then image, then text (text containing a link counts as a link).
    @MainActor
    static func save(providers: [NSItemProvider], caption: String?, into context: ModelContext) async throws -> String? {
        if let url = try await webURL(in: providers) {
            context.saveLink(url, title: caption)
            return "Link saved"
        }
        if let data = try await imageData(in: providers) {
            try context.saveImage(data: data)
            return "Screenshot saved"
        }
        if let text = try await plainText(in: providers) ?? caption, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let url = Incoming.firstURL(in: text) { context.saveLink(url, title: text) } else { context.saveNote(text) }
            return "Saved"
        }
        return nil
    }

    // loadObject (not loadItem) so iOS hands back a real URL/String whatever the sending app registered.
    private static func webURL(in providers: [NSItemProvider]) async throws -> URL? {
        for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            let url: URL? = try await withCheckedThrowingContinuation { continuation in
                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: url) }
                }
            }
            // Screenshots can also offer a file URL; those are images, not links.
            if let url, !url.isFileURL { return url }
        }
        return nil
    }

    private static func imageData(in providers: [NSItemProvider]) async throws -> Data? {
        for provider in providers {
            guard let type = provider.registeredTypeIdentifiers.first(where: { UTType($0)?.conforms(to: .image) == true })
            else { continue }
            return try await withCheckedThrowingContinuation { continuation in
                _ = provider.loadDataRepresentation(forTypeIdentifier: type) { data, error in
                    if let data { continuation.resume(returning: data) } else { continuation.resume(throwing: error ?? ImageStore.Failure()) }
                }
            }
        }
        return nil
    }

    private static func plainText(in providers: [NSItemProvider]) async throws -> String? {
        for provider in providers where provider.canLoadObject(ofClass: String.self) {
            let text: String? = try await withCheckedThrowingContinuation { continuation in
                _ = provider.loadObject(ofClass: String.self) { text, error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: text) }
                }
            }
            if let text { return text }
        }
        return nil
    }
}
