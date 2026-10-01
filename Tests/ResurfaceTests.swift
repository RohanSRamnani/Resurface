import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import XCTest
@testable import Resurface

@MainActor
final class ResurfaceTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    // MARK: Source detection

    func testSourceDetection() {
        let cases: [(String, Source)] = [
            ("https://x.com/a/status/1", .twitter),
            ("https://twitter.com/a", .twitter),
            ("https://mobile.twitter.com/a", .twitter),
            ("https://t.co/abc", .twitter),
            ("https://vm.tiktok.com/abc", .tiktok),
            ("https://www.instagram.com/p/1", .instagram),
            ("https://old.reddit.com/r/x", .reddit),
            ("https://youtu.be/abc", .youtube),
            ("https://discord.com/channels/1/2", .discord),
            ("https://lnkd.in/x", .linkedin),
            ("https://threads.net/@a", .threads),
            ("https://example.com/post", .web),
            ("https://box.com/file", .web), // ends in "x.com" but is not x.com
            ("https://notx.com", .web),
        ]
        for (string, expected) in cases {
            XCTAssertEqual(Source.detect(url: URL(string: string)!), expected, string)
        }
    }

    func testFirstURLInText() {
        XCTAssertEqual(Incoming.firstURL(in: "look at this https://x.com/a/status/1 wow")?.host, "x.com")
        XCTAssertNil(Incoming.firstURL(in: "no link here"))
        XCTAssertNil(Incoming.firstURL(in: "mailto:me@example.com"))
    }

    // MARK: Nudge planning

    func testWindowsMode() {
        var s = NudgeSettings() // morning 8:30 + evening 19:30 on by default
        s.mode = .windows
        let now = date(2026, 10, 1, 10, 0) // a Thursday, after the morning window
        let dates = NudgePlanner.fireDates(settings: s, now: now, calendar: cal, days: 3)
        XCTAssertEqual(dates, [date(2026, 10, 1, 19, 30), date(2026, 10, 2, 8, 30), date(2026, 10, 2, 19, 30),
                               date(2026, 10, 3, 8, 30), date(2026, 10, 3, 19, 30)])
    }

    func testWeekendWindowOnlyFiresOnWeekend() {
        var s = NudgeSettings()
        s.windows = FreeWindow.presets.map { var w = $0; w.enabled = w.id == "weekend"; return w }
        let dates = NudgePlanner.fireDates(settings: s, now: date(2026, 10, 1), calendar: cal, days: 7)
        XCTAssertEqual(dates, [date(2026, 10, 3, 11), date(2026, 10, 4, 11)]) // Sat, Sun
    }

    func testDigestMode() {
        var s = NudgeSettings()
        s.mode = .digest
        s.digestHour = 18
        let dates = NudgePlanner.fireDates(settings: s, now: date(2026, 10, 1, 9), calendar: cal, days: 3)
        XCTAssertEqual(dates, [date(2026, 10, 1, 18), date(2026, 10, 2, 18), date(2026, 10, 3, 18)])
    }

    func testPushOffPlansNothing() {
        var s = NudgeSettings()
        s.pushEnabled = false
        XCTAssertTrue(NudgePlanner.fireDates(settings: s, now: date(2026, 10, 1), calendar: cal).isEmpty)
    }

    func testPlanIsCappedForIOSLimit() {
        var s = NudgeSettings()
        s.windows = s.windows.map { var w = $0; w.enabled = true; return w }
        XCTAssertLessThanOrEqual(NudgePlanner.fireDates(settings: s, now: date(2026, 10, 1), calendar: cal, days: 30).count, 60)
    }

    func testNudgeCopy() {
        XCTAssertTrue(NudgePlanner.body(count: 1, topTitle: "Great post").contains("Great post"))
        XCTAssertTrue(NudgePlanner.body(count: 4, topTitle: nil).hasPrefix("4 things"))
        XCTAssertTrue(NudgePlanner.body(count: 4, topTitle: "Great post").contains("Great post"))
    }

    // MARK: Snooze

    func testSnoozeDates() {
        let now = date(2026, 10, 1, 14, 0) // Thursday
        XCTAssertEqual(SnoozeOption.threeHours.date(from: now, calendar: cal), date(2026, 10, 1, 17, 0))
        XCTAssertEqual(SnoozeOption.tomorrow.date(from: now, calendar: cal), date(2026, 10, 2, 9, 0))
        XCTAssertEqual(SnoozeOption.weekend.date(from: now, calendar: cal), date(2026, 10, 3, 10, 0)) // Saturday
        // Late night "tomorrow" is still the next calendar day.
        XCTAssertEqual(SnoozeOption.tomorrow.date(from: date(2026, 10, 1, 23, 30), calendar: cal), date(2026, 10, 2, 9, 0))
    }

    // MARK: Queue behaviour

    private func makeContext() -> ModelContext {
        ModelContext(Store.makeContainer(inMemory: true))
    }

    func testSaveLinkUsesCaptionOrHost() throws {
        let ctx = makeContext()
        let url = URL(string: "https://www.example.com/a")!
        let plain = ctx.saveLink(url)
        XCTAssertEqual(plain.title, "example.com")
        XCTAssertTrue(plain.needsTitle)

        let withCaption = ctx.saveLink(URL(string: "https://x.com/a/status/1")!, title: "Wow read this https://x.com/a/status/1")
        XCTAssertEqual(withCaption.title, "Wow read this")
        XCTAssertFalse(withCaption.needsTitle)
        XCTAssertEqual(withCaption.source, .twitter)
    }

    func testSavingSameLinkTwiceDoesNotDuplicateAndUnsnoozes() throws {
        let ctx = makeContext()
        let url = URL(string: "https://example.com/a")!
        let first = ctx.saveLink(url)
        first.snoozedUntil = .now.addingTimeInterval(9999)
        let second = ctx.saveLink(url)
        XCTAssertTrue(first === second)
        XCTAssertNil(second.snoozedUntil)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<SavedItem>()), 1)
    }

    func testReadyItemsHideSnoozedAndArchived() {
        let ctx = makeContext()
        let ready = ctx.saveLink(URL(string: "https://example.com/1")!)
        let snoozed = ctx.saveLink(URL(string: "https://example.com/2")!)
        let archived = ctx.saveLink(URL(string: "https://example.com/3")!)
        snoozed.snoozedUntil = .now.addingTimeInterval(3600)
        archived.openedAt = .now
        XCTAssertEqual(ctx.readyItems().map(\.id), [ready.id])
        // Once the snooze passes, it's back.
        XCTAssertEqual(Set(ctx.readyItems(now: .now.addingTimeInterval(7200)).map(\.id)), [ready.id, snoozed.id])
    }

    func testReadyItemsAreOldestFirst() {
        let ctx = makeContext()
        let newer = ctx.saveLink(URL(string: "https://example.com/new")!)
        let older = ctx.saveLink(URL(string: "https://example.com/old")!)
        older.savedAt = .now.addingTimeInterval(-1000)
        XCTAssertEqual(ctx.readyItems().map(\.id), [older.id, newer.id])
    }

    func testSaveNote() {
        let ctx = makeContext()
        let note = ctx.saveNote("  Book rec: The Mom Test \n")
        XCTAssertEqual(note.kind, .text)
        XCTAssertEqual(note.title, "Book rec: The Mom Test")
        XCTAssertEqual(note.source, .note)
    }

    // MARK: Screenshots

    func testSaveImageWritesAndRemovesFiles() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2000, height: 4000))
        let png = renderer.pngData { $0.fill(CGRect(x: 0, y: 0, width: 2000, height: 4000)) }
        let ctx = makeContext()
        let item = try ctx.saveImage(data: png)
        let name = try XCTUnwrap(item.imageFilename)
        let full = try XCTUnwrap(ImageStore.image(named: name))
        XCTAssertLessThanOrEqual(max(full.size.width, full.size.height) * full.scale, 1600)
        XCTAssertNotNil(ImageStore.image(named: name, thumbnail: true))
        ctx.remove(item)
        XCTAssertNil(ImageStore.image(named: name))
        XCTAssertNil(ImageStore.image(named: name, thumbnail: true))
    }

    func testSaveImageRejectsGarbage() {
        XCTAssertThrowsError(try makeContext().saveImage(data: Data("not an image".utf8)))
    }

    // MARK: Settings

    func testSettingsRoundTrip() throws {
        var s = NudgeSettings()
        s.mode = .digest
        s.windows[1].enabled = true
        let decoded = try JSONDecoder().decode(NudgeSettings.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(decoded, s)
    }

    // MARK: Share extension intake (real NSItemProviders, same code path as the extension)

    func testShareURLProvider() async throws {
        let ctx = makeContext()
        let msg = try await ShareIngest.save(providers: [NSItemProvider(object: URL(string: "https://x.com/a/status/9")! as NSURL)],
                                             caption: "Great thread https://x.com/a/status/9", into: ctx)
        XCTAssertEqual(msg, "Link saved")
        let item = try XCTUnwrap(ctx.readyItems().first)
        XCTAssertEqual(item.source, .twitter)
        XCTAssertEqual(item.title, "Great thread")
    }

    func testShareImageProvider() async throws {
        let ctx = makeContext()
        let png = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 600)).pngData { $0.fill(CGRect(x: 0, y: 0, width: 300, height: 600)) }
        let provider = NSItemProvider(item: png as NSData, typeIdentifier: UTType.png.identifier)
        let msg = try await ShareIngest.save(providers: [provider], caption: nil, into: ctx)
        XCTAssertEqual(msg, "Screenshot saved")
        let item = try XCTUnwrap(ctx.readyItems().first)
        XCTAssertEqual(item.kind, .image)
        XCTAssertNotNil(ImageStore.image(named: try XCTUnwrap(item.imageFilename)))
    }

    func testShareImageFileWithFileURLIsNotTreatedAsLink() async throws {
        // A screenshot preview can register both an image and a file URL; the image must win.
        let ctx = makeContext()
        let png = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).pngData { $0.fill(CGRect(x: 0, y: 0, width: 100, height: 100)) }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("shot.png")
        try png.write(to: file)
        let provider = try XCTUnwrap(NSItemProvider(contentsOf: file))
        _ = try await ShareIngest.save(providers: [provider], caption: nil, into: ctx)
        XCTAssertEqual(ctx.readyItems().first?.kind, .image)
    }

    func testShareTextWithLinkBecomesLink() async throws {
        let ctx = makeContext()
        let msg = try await ShareIngest.save(providers: [NSItemProvider(object: "see https://example.com/post now" as NSString)], caption: nil, into: ctx)
        XCTAssertEqual(msg, "Saved")
        let item = try XCTUnwrap(ctx.readyItems().first)
        XCTAssertEqual(item.kind, .link)
        XCTAssertEqual(item.url?.host, "example.com")
    }

    func testSharePlainTextBecomesNote() async throws {
        let ctx = makeContext()
        _ = try await ShareIngest.save(providers: [NSItemProvider(object: "Remember to read about SQLite WAL" as NSString)], caption: nil, into: ctx)
        XCTAssertEqual(ctx.readyItems().first?.kind, .text)
    }

    func testShareNothingUsable() async throws {
        let ctx = makeContext()
        let msg = try await ShareIngest.save(providers: [], caption: "  ", into: ctx)
        XCTAssertNil(msg)
        XCTAssertTrue(ctx.readyItems().isEmpty)
    }

    // MARK: Opening

    func testOpeningLinkArchivesItAndCallsOpenURL() {
        let ctx = makeContext()
        let item = ctx.saveLink(URL(string: "https://example.com/a")!)
        item.snoozedUntil = .now.addingTimeInterval(3600)
        var opened: URL?
        Router().open(item, context: ctx, openURL: OpenURLAction { opened = $0; return .handled })
        XCTAssertEqual(opened, item.url)
        XCTAssertTrue(item.isArchived)
        XCTAssertNil(item.snoozedUntil)
        XCTAssertTrue(ctx.readyItems().isEmpty)
    }

    func testOpeningNotePresentsSheetAndKeepsFirstOpenDate() {
        let ctx = makeContext()
        let note = ctx.saveNote("hello")
        let router = Router()
        router.open(note, context: ctx, openURL: OpenURLAction { _ in .handled })
        XCTAssertTrue(router.presented === note)
        let firstOpen = note.openedAt
        router.open(note, context: ctx, openURL: OpenURLAction { _ in .handled }) // re-open from archive
        XCTAssertEqual(note.openedAt, firstOpen)
    }
}
