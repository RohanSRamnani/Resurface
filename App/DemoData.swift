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
        func add(_ url: String, _ title: String, daysAgo: Double, opened: Double? = nil, snoozedFor: Double? = nil) {
            let link = URL(string: url)!
            let item = SavedItem(kind: .link, url: link, title: title, source: .detect(url: link),
                                 savedAt: .now.addingTimeInterval(-daysAgo * day))
            item.openedAt = opened.map { .now.addingTimeInterval(-$0 * day) }
            item.snoozedUntil = snoozedFor.map { .now.addingTimeInterval($0 * day) }
            context.insert(item)
        }
        // Queue: what a real week of saving looks like.
        add("https://x.com/indiebuilds/status/1841200093318", "Thread: how we got our first 100 paying users without ads", daysAgo: 6)
        add("https://www.tiktok.com/@kitchencrush/video/7421003311", "15-minute crispy gnocchi, one pan", daysAgo: 4)
        add("https://www.reddit.com/r/iOSProgramming/comments/1fq2x7/", "Share extensions + SwiftData: what actually works", daysAgo: 3)
        add("https://discord.com/channels/9102/4431/88120", "Pinned in #launch: the pre-launch checklist", daysAgo: 2.5)
        add("https://www.youtube.com/watch?v=Kz3pQ0mLx8", "SwiftUI animations that feel native, full walkthrough", daysAgo: 2)
        add("https://paulgraham.com/greatwork.html", "How to Do Great Work", daysAgo: 0.4)
        if let data = sampleScreenshot(), let name = try? ImageStore.save(data: data) {
            context.insert(SavedItem(kind: .image, title: "Screenshot", source: .screenshot,
                                     imageFilename: name, savedAt: .now.addingTimeInterval(-5 * day)))
        }
        context.insert(SavedItem(kind: .text, title: "Book rec from Sam: The Mom Test", text: "Book rec from Sam: The Mom Test (Rob Fitzpatrick). Read before customer calls.",
                                 source: .note, savedAt: .now.addingTimeInterval(-1 * day)))
        // Snoozed and archived, so every section has something in it.
        add("https://www.linkedin.com/posts/founding-ios-engineer", "Hiring: founding iOS engineer, worth a reply", daysAgo: 1, snoozedFor: 1)
        add("https://x.com/coldemailclub/status/1838812", "Cold email templates that actually get replies", daysAgo: 9, opened: 1)
        add("https://www.tiktok.com/@mobilitymike/video/7419", "10-minute morning mobility routine", daysAgo: 8, opened: 3)
        add("https://www.youtube.com/watch?v=dk3Wq9", "Designing for dark mode, the right way", daysAgo: 12, opened: 4)
        context.commit()
    }

    /// A believable phone screenshot of a post, so screenshot rows don't look blank.
    private static func sampleScreenshot() -> Data? {
        let size = CGSize(width: 1179, height: 2556)
        return UIGraphicsImageRenderer(size: size).jpegData(withCompressionQuality: 0.9) { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor(white: 0.35, alpha: 1).setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 72, y: 760, width: 130, height: 130))
            let white: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 52, weight: .bold), .foregroundColor: UIColor.white]
            let grey: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 46), .foregroundColor: UIColor.lightGray]
            ("Maya Chen" as NSString).draw(at: CGPoint(x: 236, y: 772), withAttributes: white)
            ("@mayabuilds · 3h" as NSString).draw(at: CGPoint(x: 236, y: 836), withAttributes: grey)
            let body = "Pricing tip nobody told me:\n\ncharge for the outcome, not the hours. Our churn dropped 40% the month we switched."
            (body as NSString).draw(in: CGRect(x: 72, y: 960, width: 1035, height: 700),
                                    withAttributes: [.font: UIFont.systemFont(ofSize: 66, weight: .medium), .foregroundColor: UIColor.white])
            ("1.2K   ·   318   ·   4.9K" as NSString).draw(at: CGPoint(x: 72, y: 1560), withAttributes: grey)
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
