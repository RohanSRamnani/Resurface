#if DEBUG
import SwiftData
import UIKit

/// Debug-only launch arguments for QA and screenshots:
///   -resetData       wipe the store before launch
///   -skipOnboarding  mark onboarding done
///   -seedDemo        insert sample items (only when the store is empty)
enum DemoData {
    private static var args: [String] { ProcessInfo.processInfo.arguments }

    static func prepare() {
        if args.contains("-resetData") {
            try? FileManager.default.removeItem(at: Store.directory.appendingPathComponent("images"))
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: Store.directory.appendingPathComponent("resurface.store" + suffix))
            }
            Store.defaults.removeObject(forKey: "nudgeSettings")
        }
        if args.contains("-skipOnboarding") {
            var settings = NudgeSettings.load()
            settings.onboarded = true
            settings.save()
        }
    }

    @MainActor static func seed(_ container: ModelContainer) {
        guard args.contains("-seedDemo") else { return }
        let context = container.mainContext
        guard ((try? context.fetchCount(FetchDescriptor<SavedItem>())) ?? 0) == 0 else { return }
        let day: TimeInterval = 86400
        let links: [(String, String, TimeInterval)] = [
            ("https://x.com/naval/status/1002103360646823936", "How to get rich (without getting lucky)", 6),
            ("https://www.tiktok.com/@chef/video/7300000000000000001", "The 5-minute pasta everyone is making", 4),
            ("https://www.reddit.com/r/macapps/comments/abc123", "Best menu bar apps of the year", 3),
            ("https://www.youtube.com/watch?v=dQw4w9WgXcQ", "Never gonna give you up (full talk)", 2),
            ("https://www.instagram.com/p/abc123", "Apartment tour: 400 sq ft done right", 1),
            ("https://paulgraham.com/greatwork.html", "How to Do Great Work", 0.5),
        ]
        for (url, title, age) in links {
            context.insert(SavedItem(kind: .link, url: URL(string: url), title: title,
                                     source: .detect(url: URL(string: url)!), savedAt: .now.addingTimeInterval(-age * day)))
        }
        if let data = sampleImage(text: "Great thread on pricing"), let name = try? ImageStore.save(data: data) {
            context.insert(SavedItem(kind: .image, title: "Screenshot", source: .screenshot,
                                     imageFilename: name, savedAt: .now.addingTimeInterval(-5 * day)))
        }
        context.insert(SavedItem(kind: .text, title: "Book rec from Sam: The Mom Test", text: "Book rec from Sam: The Mom Test", source: .note,
                                 savedAt: .now.addingTimeInterval(-2 * day)))
        let done = SavedItem(kind: .link, url: URL(string: "https://x.com/paulg/status/1"), title: "Startup ideas thread", source: .twitter,
                             savedAt: .now.addingTimeInterval(-9 * day))
        done.openedAt = .now.addingTimeInterval(-1 * day)
        context.insert(done)
        let done2 = SavedItem(kind: .link, url: URL(string: "https://www.tiktok.com/@a/video/2"), title: "Stretching routine", source: .tiktok,
                              savedAt: .now.addingTimeInterval(-8 * day))
        done2.openedAt = .now.addingTimeInterval(-3 * day)
        context.insert(done2)
        let snoozed = SavedItem(kind: .link, url: URL(string: "https://www.linkedin.com/posts/x"), title: "Hiring post worth replying to", source: .linkedin,
                                savedAt: .now.addingTimeInterval(-1 * day))
        snoozed.snoozedUntil = .now.addingTimeInterval(day)
        context.insert(snoozed)
        context.commit()
    }

    private static func sampleImage(text: String) -> Data? {
        UIGraphicsImageRenderer(size: CGSize(width: 1170, height: 2532)).jpegData(withCompressionQuality: 0.9) { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1170, height: 2532))
            (text as NSString).draw(at: CGPoint(x: 80, y: 400),
                                    withAttributes: [.font: UIFont.boldSystemFont(ofSize: 90), .foregroundColor: UIColor.white])
        }
    }
}
#endif

/// `-tab 1` / `-onboardingPage 2` style launch arguments, debug builds only (nil in release).
enum DebugArgs {
    static func int(_ name: String) -> Int? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        return args.firstIndex(of: name).flatMap { args.indices.contains($0 + 1) ? Int(args[$0 + 1]) : nil }
        #else
        return nil
        #endif
    }
}
