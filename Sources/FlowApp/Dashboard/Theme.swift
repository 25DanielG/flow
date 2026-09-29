import FlowHistory
import AppKit
import SwiftUI

enum Theme {
    static let sidebarBackground = Color(nsColor: .underPageBackgroundColor)
    static let contentBackground = Color(nsColor: .windowBackgroundColor)
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let hairline = Color.primary.opacity(0.08)
    static let pagePadding: CGFloat = 32
    static let topInset: CGFloat = 44 // traffic lights
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.hairline))
    }
}

struct PageHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 26, weight: .semibold))
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct Eyebrow: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(.tertiary)
    }
}

struct SubtleButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .background(
                Capsule().fill(prominent ? Color.accentColor : Color.primary.opacity(0.08))
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

@MainActor
enum AppIcons {
    private static var cache: [String: NSImage] = [:]

    static func icon(for bundleID: String) -> NSImage? {
        if let cached = cache[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        cache[bundleID] = image
        return image
    }
}

struct AppGlyph: View {
    let bundleID: String?
    var siteHost: String?
    var size: CGFloat = 24

    var body: some View {
        if let bundleID, let image = AppIcons.icon(for: bundleID) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
        } else {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(Color.primary.opacity(0.07))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: siteHost != nil ? "globe" : (bundleID != nil ? "app.dashed" : "waveform"))
                        .font(.system(size: size * 0.45, weight: .regular))
                        .foregroundStyle(.secondary)
                )
        }
    }
}

struct Insights {
    struct Entry: Identifiable {
        let id: String
        let name: String
        let bundleID: String?
        let count: Int
    }

    let dictations: Int
    let words: Int
    let minutes: Double
    let apps: [Entry]
    let sites: [Entry]

    init(records: [DictationRecord]) {
        dictations = records.count
        words = records.reduce(0) { $0 + $1.finalText.split(whereSeparator: \.isWhitespace).count }
        minutes = records.reduce(0) { $0 + $1.audioDuration } / 60

        var appCounts: [String: (name: String, count: Int)] = [:]
        var siteCounts: [String: Int] = [:]
        for record in records {
            if let id = record.appBundleID {
                appCounts[id, default: (record.appName ?? id, 0)].count += 1
            }
            if let host = record.siteHost {
                siteCounts[host, default: 0] += 1
            }
        }
        apps = appCounts.map { Entry(id: $0.key, name: $0.value.name, bundleID: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
        sites = siteCounts.map { Entry(id: $0.key, name: $0.key, bundleID: nil, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
}
