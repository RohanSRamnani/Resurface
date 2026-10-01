import SwiftUI

enum Theme {
    static let accent = Color(red: 0.36, green: 0.36, blue: 0.84)
}

/// Where a saved thing came from. Detected from the URL host, so grouping needs no manual work.
enum Source: String, CaseIterable, Codable {
    case twitter, tiktok, instagram, reddit, youtube, discord, linkedin, threads, web, screenshot, note

    var displayName: String {
        switch self {
        case .twitter: "X / Twitter"
        case .tiktok: "TikTok"
        case .instagram: "Instagram"
        case .reddit: "Reddit"
        case .youtube: "YouTube"
        case .discord: "Discord"
        case .linkedin: "LinkedIn"
        case .threads: "Threads"
        case .web: "Web"
        case .screenshot: "Screenshots"
        case .note: "Notes"
        }
    }

    var symbol: String {
        switch self {
        case .twitter: "bubble.left.fill"
        case .tiktok: "music.note"
        case .instagram: "camera.fill"
        case .reddit: "text.bubble.fill"
        case .youtube: "play.rectangle.fill"
        case .discord: "message.fill"
        case .linkedin: "briefcase.fill"
        case .threads: "at"
        case .web: "safari.fill"
        case .screenshot: "photo.fill"
        case .note: "note.text"
        }
    }

    var color: Color {
        switch self {
        case .twitter: .blue
        case .tiktok: .pink
        case .instagram: .purple
        case .reddit: .orange
        case .youtube: .red
        case .discord: .indigo
        case .linkedin: .cyan
        case .threads: .gray
        case .web: .teal
        case .screenshot: .green
        case .note: .yellow
        }
    }

    private static let domains: [(Source, [String])] = [
        (.twitter, ["twitter.com", "x.com", "t.co", "fxtwitter.com", "vxtwitter.com", "fixupx.com"]),
        (.tiktok, ["tiktok.com"]),
        (.instagram, ["instagram.com", "instagr.am"]),
        (.reddit, ["reddit.com", "redd.it"]),
        (.youtube, ["youtube.com", "youtu.be"]),
        (.discord, ["discord.com", "discord.gg", "discordapp.com"]),
        (.linkedin, ["linkedin.com", "lnkd.in"]),
        (.threads, ["threads.net", "threads.com"]),
    ]

    static func detect(url: URL) -> Source {
        guard let host = url.host?.lowercased() else { return .web }
        for (source, list) in domains where list.contains(where: { host == $0 || host.hasSuffix("." + $0) }) {
            return source
        }
        return .web
    }
}

/// Pulls a web link out of shared text (apps often share "check this out https://…").
enum Incoming {
    static func firstURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        return detector?.matches(in: text, range: range)
            .compactMap(\.url)
            .first { ["http", "https"].contains($0.scheme?.lowercased()) }
    }
}
