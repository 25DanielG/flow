import AppKit
import FlowClaude
import FlowHistory
import FlowProfiles
import FlowVocabulary
import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case history = "History"
    case profiles = "Profiles"
    case vocabulary = "Vocabulary"
    case settings = "Settings"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .home: "waveform"
        case .history: "clock"
        case .profiles: "slider.horizontal.3"
        case .vocabulary: "character.book.closed"
        case .settings: "gearshape"
        }
    }
}

// not NavigationSplitView, blank render bug with mixed fixed/flexible siblings
struct RootView: View {
    @ObservedObject var historyStore: HistoryStore
    @ObservedObject var profileStore: ProfileStore
    @ObservedObject var vocabularyStore: VocabularyStore
    @ObservedObject var status: AppStatus
    let permissions: PermissionsManager

    @State private var selection: SidebarSection =
        SidebarSection.allCases.first { $0.rawValue.lowercased() == DebugSnapshot.startSection } ?? .home

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(selection: $selection, status: status)
                .frame(width: 200)
            Rectangle().fill(Theme.hairline).frame(width: 1)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.contentBackground)
        }
        .ignoresSafeArea()
        .frame(minWidth: 820, minHeight: 560)
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .home:
            HomeView(
                historyStore: historyStore, status: status,
                openHistory: { selection = .history }, openSettings: { selection = .settings }
            )
        case .history:
            HistoryView(store: historyStore)
        case .profiles:
            ProfilesView(store: profileStore, history: historyStore)
        case .vocabulary:
            VocabularyView(store: vocabularyStore)
        case .settings:
            SettingsView(permissions: permissions)
        }
    }
}

private struct Sidebar: View {
    @Binding var selection: SidebarSection
    @ObservedObject var status: AppStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 15, weight: .semibold))
                Text("Flow")
                    .font(.system(size: 15, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.top, Theme.topInset)
            .padding(.bottom, 18)

            ForEach(SidebarSection.allCases) { section in
                SidebarRow(section: section, isSelected: selection == section) {
                    selection = section
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(status.state == .idle ? Color.secondary.opacity(0.4) : Color.red)
                    .frame(width: 6, height: 6)
                Text(status.state == .idle ? "Hold fn to dictate" : "Listening")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 8)
        .frame(maxHeight: .infinity)
        .background(Theme.sidebarBackground)
    }
}

private struct SidebarRow: View {
    let section: SidebarSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: section.symbol)
                    .font(.system(size: 13))
                    .frame(width: 18)
                Text(section.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
