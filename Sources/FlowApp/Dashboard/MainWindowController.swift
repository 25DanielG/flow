import AppKit
import FlowHistory
import FlowProfiles
import FlowVocabulary
import SwiftUI

@MainActor
final class MainWindowController {
    private var window: NSWindow?
    private let historyStore: HistoryStore
    private let profileStore: ProfileStore
    private let vocabularyStore: VocabularyStore
    private let status: AppStatus
    private let permissions: PermissionsManager

    init(
        historyStore: HistoryStore, profileStore: ProfileStore, vocabularyStore: VocabularyStore,
        status: AppStatus, permissions: PermissionsManager
    ) {
        self.historyStore = historyStore
        self.profileStore = profileStore
        self.vocabularyStore = vocabularyStore
        self.status = status
        self.permissions = permissions
    }

    func show() {
        if window == nil { window = makeWindow() }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        if let window { DebugSnapshot.captureIfRequested(window) }
    }

    private func makeWindow() -> NSWindow {
        let root = RootView(
            historyStore: historyStore, profileStore: profileStore, vocabularyStore: vocabularyStore,
            status: status, permissions: permissions
        )
        let hosting = NSHostingView(rootView: root)
        hosting.sizingOptions = []

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.title = "Flow"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.contentMinSize = NSSize(width: 820, height: 560)
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("FlowMainWindow")
        if !window.setFrameUsingName("FlowMainWindow") { window.center() }
        return window
    }
}
