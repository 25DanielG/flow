import AppKit
import FlowClaude
import FlowHistory
import SwiftUI

struct HomeView: View {
    @ObservedObject var historyStore: HistoryStore
    @ObservedObject var status: AppStatus
    let openHistory: () -> Void
    let openSettings: () -> Void

    @State private var refresh = 0

    private var insights: Insights { Insights(records: historyStore.records) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header
                banner
                stats
                whereYouDictate
                recent
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, Theme.topInset)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh += 1
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "waveform")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(status.state == .idle ? Color.secondary : Color.red)
                .symbolEffect(.variableColor.iterative, isActive: status.state != .idle)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.primary.opacity(0.06)))
            VStack(alignment: .leading, spacing: 3) {
                Text(headline)
                    .font(.system(size: 22, weight: .semibold))
                Text(subheadline)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var headline: String {
        switch status.state {
        case .idle: "Ready"
        case .recording: "Listening…"
        case .locked: "Listening, hands-free…"
        }
    }

    private var subheadline: String {
        if let routing = status.lastRouting, status.state == .idle {
            return "Last used: \(routing)"
        }
        return "Hold fn to dictate. Double-tap fn to lock it on."
    }

    // MARK: API key / error banner

    @ViewBuilder
    private var banner: some View {
        let _ = refresh
        if let notice = status.notice {
            Banner(text: notice, actionTitle: nil, action: {})
        } else if !AnthropicAPIKey.isConfigured {
            Banner(
                text: "Add your Anthropic API key to turn on cleanup. Until then Flow types the raw transcript.",
                actionTitle: "Add key", action: openSettings
            )
        }
    }

    // MARK: Stats

    private var stats: some View {
        let insights = insights
        return HStack(alignment: .top, spacing: 0) {
            Stat(value: "\(insights.dictations)", label: "Dictations")
            Stat(value: Self.compact(insights.words), label: "Words")
            Stat(value: Self.minutes(insights.minutes), label: "Minutes spoken")
        }
    }

    private static func compact(_ n: Int) -> String {
        n >= 10_000 ? String(format: "%.1fk", Double(n) / 1000) : "\(n)"
    }

    private static func minutes(_ m: Double) -> String {
        m < 10 ? String(format: "%.1f", m) : "\(Int(m.rounded()))"
    }

    // MARK: Where you dictate

    @ViewBuilder
    private var whereYouDictate: some View {
        let insights = insights
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow("Where you dictate")
            if insights.apps.isEmpty {
                Text("Apps you dictate in will show up here.")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            } else {
                HStack(alignment: .top, spacing: 22) {
                    ForEach(insights.apps.prefix(6)) { entry in
                        VStack(spacing: 6) {
                            AppGlyph(bundleID: entry.bundleID, size: 44)
                            Text(entry.name)
                                .font(.system(size: 11))
                                .lineLimit(1)
                                .frame(maxWidth: 64)
                            Text("\(entry.count)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .help("\(entry.name) — \(entry.count) dictations")
                    }
                }
                if !insights.sites.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(insights.sites.prefix(6)) { site in
                            HStack(spacing: 5) {
                                Text(site.name)
                                Text("\(site.count)").foregroundStyle(.tertiary).monospacedDigit()
                            }
                            .font(.system(size: 11))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.primary.opacity(0.06)))
                        }
                    }
                }
            }
        }
    }

    // MARK: Recent

    @ViewBuilder
    private var recent: some View {
        let records = Array(historyStore.records.prefix(5))
        if !records.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Eyebrow("Recent")
                    Spacer()
                    Button("See all", action: openHistory)
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 0) {
                    ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                        if index > 0 { Rectangle().fill(Theme.hairline).frame(height: 1) }
                        HStack(alignment: .top, spacing: 12) {
                            AppGlyph(bundleID: record.appBundleID, siteHost: record.siteHost, size: 20)
                                .padding(.top, 1)
                            Text(record.finalText)
                                .font(.system(size: 13))
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(HistoryFormat.relative(record.timestamp))
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 11)
                    }
                }
            }
        }
    }
}

private struct Stat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 34, weight: .light, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Banner: View {
    let text: String
    let actionTitle: String?
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.orange)
            Text(text)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)
            if let actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(SubtleButtonStyle(prominent: true))
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

@MainActor
enum HistoryFormat {
    private static let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    static func relative(_ date: Date) -> String {
        formatter.localizedString(for: date, relativeTo: Date())
    }
}
