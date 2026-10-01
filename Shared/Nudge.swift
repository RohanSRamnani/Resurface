import Foundation
import SwiftData
import UserNotifications

struct FreeWindow: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var symbol: String
    var hour: Int
    var minute: Int
    var weekdays: Set<Int> // Calendar weekday: 1 = Sunday … 7 = Saturday
    var enabled: Bool

    static let allDays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]

    static let presets: [FreeWindow] = [
        FreeWindow(id: "morning", name: "Morning coffee", symbol: "cup.and.saucer.fill", hour: 8, minute: 30, weekdays: allDays, enabled: true),
        FreeWindow(id: "lunch", name: "Lunch break", symbol: "fork.knife", hour: 12, minute: 30, weekdays: allDays, enabled: false),
        FreeWindow(id: "evening", name: "Evening wind-down", symbol: "moon.stars.fill", hour: 19, minute: 30, weekdays: allDays, enabled: true),
        FreeWindow(id: "weekend", name: "Weekend", symbol: "sun.max.fill", hour: 11, minute: 0, weekdays: [1, 7], enabled: false),
    ]

    /// Time-of-day as a Date, for DatePicker binding.
    var time: Date {
        get { Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now }
        set {
            hour = Calendar.current.component(.hour, from: newValue)
            minute = Calendar.current.component(.minute, from: newValue)
        }
    }
}

enum NudgeMode: String, Codable, CaseIterable {
    case windows, digest
}

struct NudgeSettings: Codable, Equatable {
    var onboarded = false
    var pushEnabled = true
    var mode: NudgeMode = .windows
    var windows = FreeWindow.presets
    var digestHour = 18
    var digestMinute = 0

    var digestTime: Date {
        get { Calendar.current.date(bySettingHour: digestHour, minute: digestMinute, second: 0, of: .now) ?? .now }
        set {
            digestHour = Calendar.current.component(.hour, from: newValue)
            digestMinute = Calendar.current.component(.minute, from: newValue)
        }
    }

    private static let key = "nudgeSettings"

    static func load() -> NudgeSettings {
        guard let data = Store.defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(NudgeSettings.self, from: data) else { return NudgeSettings() }
        return decoded
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { Store.defaults.set(data, forKey: Self.key) }
    }
}

enum NudgePlanner {
    /// When to fire over the next `days` days. Pure so it can be tested without notifications.
    static func fireDates(settings: NudgeSettings, now: Date = .now, calendar: Calendar = .current,
                          days: Int = 14, limit: Int = 60) -> [Date] {
        guard settings.pushEnabled else { return [] }
        let start = calendar.startOfDay(for: now)
        var dates = Set<Date>()
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            let slots: [(Int, Int)] = switch settings.mode {
            case .digest: [(settings.digestHour, settings.digestMinute)]
            case .windows: settings.windows.filter { $0.enabled && $0.weekdays.contains(weekday) }.map { ($0.hour, $0.minute) }
            }
            for (hour, minute) in slots {
                if let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day), date > now {
                    dates.insert(date)
                }
            }
        }
        return Array(dates.sorted().prefix(limit))
    }

    static func body(count: Int, topTitle: String?) -> String {
        let top = topTitle.map { "“\(String($0.prefix(60)))”" }
        switch (count, top) {
        case (1, let top?): return "\(top) is waiting. Got a couple of minutes?"
        case (1, nil): return "1 thing is waiting. Got a couple of minutes?"
        case (_, let top?): return "\(count) things you saved are waiting. Start with \(top)?"
        default: return "\(count) things you saved are waiting. Got 10 minutes?"
        }
    }
}

enum SnoozeOption: CaseIterable {
    case threeHours, tomorrow, weekend

    var label: String {
        switch self {
        case .threeHours: "In 3 hours"
        case .tomorrow: "Tomorrow morning"
        case .weekend: "This weekend"
        }
    }

    func date(from now: Date = .now, calendar: Calendar = .current) -> Date {
        switch self {
        case .threeHours:
            return now.addingTimeInterval(3 * 3600)
        case .tomorrow:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        case .weekend:
            return calendar.nextDate(after: now, matching: DateComponents(hour: 10, weekday: 7),
                                     matchingPolicy: .nextTime) ?? now.addingTimeInterval(86400)
        }
    }
}

enum NudgeScheduler {
    static let idPrefix = "resurface.nudge."

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Replace all pending nudges with a fresh plan. Nothing is scheduled while the queue is empty.
    /// ponytail: plans 14 days ahead and the body is frozen at plan time; it refreshes whenever the
    /// app opens or anything is saved/opened. Add a background refresh task if staleness matters.
    static func reschedule(context: ModelContext, now: Date = .now) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let ready = context.readyItems(now: now)
        guard !ready.isEmpty else { return }
        let body = NudgePlanner.body(count: ready.count, topTitle: ready.first?.title)
        for date in NudgePlanner.fireDates(settings: .load(), now: now) {
            let content = UNMutableNotificationContent()
            content.title = "Resurface"
            content.body = body
            content.sound = .default
            content.interruptionLevel = .passive
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            center.add(UNNotificationRequest(
                identifier: idPrefix + String(Int(date.timeIntervalSince1970)),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
        }
    }
}
