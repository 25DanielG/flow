import AppKit
import FlowHistory
import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: HistoryStore
    @State private var query = ""
    @State private var expandedID: UUID?
    @State private var confirmClear = false

    private var filtered: [DictationRecord] {
        guard !query.isEmpty else { return store.records }
        return store.records.filter {
            $0.finalText.localizedCaseInsensitiveContains(query)
                || $0.rawText.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 20)

                if store.records.isEmpty {
                    Text("Nothing yet. What you dictate shows up here.")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                } else if filtered.isEmpty {
                    Text("No matches.")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, record in
                        if index > 0 { Rectangle().fill(Theme.hairline).frame(height: 1) }
                        HistoryRow(record: record, expanded: expandedID == record.id) {
                            expandedID = expandedID == record.id ? nil : record.id
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, Theme.topInset)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .confirmationDialog("Clear all history?", isPresented: $confirmClear) {
            Button("Clear History", role: .destructive) { store.clear() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                PageHeader(title: "History")
                Spacer()
                if !store.records.isEmpty {
                    Button("Clear") { confirmClear = true }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                TextField("Search", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }
}

private struct HistoryRow: View {
    let record: DictationRecord
    let expanded: Bool
    let toggle: () -> Void

    @State private var hovering = false
    @State private var copied = false

    private var place: String? {
        record.siteHost ?? record.appName
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            AppGlyph(bundleID: record.appBundleID, siteHost: record.siteHost, size: 26)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 6) {
                Text(record.finalText)
                    .font(.system(size: 13.5))
                    .lineLimit(expanded ? nil : 3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    if let place {
                        Text(place)
                        dot
                    }
                    Text(record.profileName)
                    dot
                    Text(String(format: "%.0fs", record.audioDuration))
                    dot
                    Text(HistoryFormat.relative(record.timestamp))
                    if !record.wasPostProcessed {
                        dot
                        Text("raw").foregroundStyle(.orange)
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

                if expanded, record.rawText != record.finalText {
                    VStack(alignment: .leading, spacing: 3) {
                        Eyebrow("As heard")
                        Text(record.rawText)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.top, 6)
                }
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(record.finalText, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .opacity(hovering || copied ? 1 : 0)
            .help("Copy")
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture(perform: toggle)
        .onHover { hovering = $0 }
    }

    private var dot: some View {
        Text("·")
    }
}
