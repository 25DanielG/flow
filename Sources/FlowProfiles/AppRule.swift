import Foundation

// all set fields must match, first match wins
public struct AppRule: Codable, Equatable, Sendable {
    public var label: String
    public var bundleID: String?
    // substring of address bar
    public var host: String?
    // substring of window title
    public var titleContains: String?
    public var profileID: String

    public init(label: String, bundleID: String? = nil, host: String? = nil, titleContains: String? = nil, profileID: String) {
        self.label = label
        self.bundleID = bundleID
        self.host = host
        self.titleContains = titleContains
        self.profileID = profileID
    }

    public func matches(bundleID actualBundleID: String?, url: String?, title: String?) -> Bool {
        // no criteria would match everything
        guard bundleID != nil || host != nil || titleContains != nil else { return false }
        if let bundleID, bundleID.caseInsensitiveCompare(actualBundleID ?? "") != .orderedSame { return false }
        if let host, url?.range(of: host, options: .caseInsensitive) == nil { return false }
        if let titleContains, title?.range(of: titleContains, options: .caseInsensitive) == nil { return false }
        return true
    }
}

public enum DefaultAppRules {
    public static let all: [AppRule] = [
        // sites first
        AppRule(label: "Gmail", host: "mail.google.com", profileID: "email"),
        AppRule(label: "Outlook (web)", host: "outlook.live.com", profileID: "email"),
        AppRule(label: "Outlook (web)", host: "outlook.office.com", profileID: "email"),
        AppRule(label: "Outlook (web)", host: "outlook.office365.com", profileID: "email"),
        AppRule(label: "Slack (web)", host: "app.slack.com", profileID: "message"),
        AppRule(label: "Discord (web)", host: "discord.com", profileID: "message"),
        AppRule(label: "WhatsApp (web)", host: "web.whatsapp.com", profileID: "message"),
        AppRule(label: "Google Messages", host: "messages.google.com", profileID: "message"),
        AppRule(label: "Claude", host: "claude.ai", profileID: "prompt-building"),
        AppRule(label: "ChatGPT", host: "chatgpt.com", profileID: "prompt-building"),
        AppRule(label: "ChatGPT", host: "chat.openai.com", profileID: "prompt-building"),
        AppRule(label: "Gemini", host: "gemini.google.com", profileID: "prompt-building"),
        AppRule(label: "Google Docs", host: "docs.google.com", profileID: "writing"),
        // apps
        AppRule(label: "Mail", bundleID: "com.apple.mail", profileID: "email"),
        AppRule(label: "Outlook", bundleID: "com.microsoft.Outlook", profileID: "email"),
        AppRule(label: "Spark", bundleID: "com.readdle.smartemail-Mac", profileID: "email"),
        AppRule(label: "Messages", bundleID: "com.apple.MobileSMS", profileID: "message"),
        AppRule(label: "Slack", bundleID: "com.tinyspeck.slackmacgap", profileID: "message"),
        AppRule(label: "Discord", bundleID: "com.hnc.Discord", profileID: "message"),
        AppRule(label: "Telegram", bundleID: "ru.keepcoder.Telegram", profileID: "message"),
        AppRule(label: "WhatsApp", bundleID: "net.whatsapp.WhatsApp", profileID: "message"),
        AppRule(label: "Teams", bundleID: "com.microsoft.teams2", profileID: "message"),
        AppRule(label: "Claude", bundleID: "com.anthropic.claudefordesktop", profileID: "prompt-building"),
        AppRule(label: "ChatGPT", bundleID: "com.openai.chat", profileID: "prompt-building"),
        AppRule(label: "Terminal", bundleID: "com.apple.Terminal", profileID: "prompt-building"),
        AppRule(label: "iTerm", bundleID: "com.googlecode.iterm2", profileID: "prompt-building"),
        AppRule(label: "Ghostty", bundleID: "com.mitchellh.ghostty", profileID: "prompt-building"),
        AppRule(label: "Warp", bundleID: "dev.warp.Warp-Stable", profileID: "prompt-building"),
        AppRule(label: "VS Code", bundleID: "com.microsoft.VSCode", profileID: "prompt-building"),
        AppRule(label: "Cursor", bundleID: "com.todesktop.230313mzl4w4u92", profileID: "prompt-building")
    ]
}
