import AppKit

// dev only: FLOW_SNAPSHOT=/tmp/out.png renders window to png and exits
enum DebugSnapshot {
    static var startSection: String? {
        ProcessInfo.processInfo.environment["FLOW_START_SECTION"]
    }

    @MainActor
    static func captureIfRequested(_ window: NSWindow) {
        guard let path = ProcessInfo.processInfo.environment["FLOW_SNAPSHOT"] else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard let view = window.contentView,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)
            else { exit(1) }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
            exit(0)
        }
    }
}
