import AppKit
import SwiftUI

// pill only gets rounding from the effect view, a 2nd bg in swiftui made a halo
@MainActor
public final class WaveformPanelController {
    public let state = WaveformState()
    private let panel: NSPanel
    private let effectView: NSVisualEffectView
    private let hostingView: NSHostingView<WaveformView>

    public init() {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 100, height: 36)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false

        let effectView = NSVisualEffectView()
        effectView.appearance = NSAppearance(named: .vibrantDark)
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true

        let hostingView = NSHostingView(rootView: WaveformView(state: state))
        hostingView.sizingOptions = [.intrinsicContentSize]

        effectView.addSubview(hostingView)
        panel.contentView = effectView

        self.panel = panel
        self.effectView = effectView
        self.hostingView = hostingView
    }

    public func show() {
        sizeToFitContent()
        let targetOrigin = bottomOfScreenOrigin()
        let startOrigin = NSPoint(x: targetOrigin.x, y: targetOrigin.y - 10)

        panel.alphaValue = 0
        panel.setFrameOrigin(startOrigin)
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrameOrigin(targetOrigin)
        }
    }

    public func flash(_ message: String, duration: TimeInterval = 3) {
        state.message = message
        // wait for layout
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.show()
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                guard let self, self.state.message == message else { return }
                self.hide()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if self.state.message == message { self.state.message = nil }
                }
            }
        }
    }

    public func hide() {
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
            },
            completionHandler: { [panel] in
                Task { @MainActor in panel.orderOut(nil) }
            }
        )
    }

    private func sizeToFitContent() {
        let fitting = hostingView.fittingSize
        let size = NSSize(width: max(fitting.width, 24), height: max(fitting.height, 14))

        var frame = panel.frame
        frame.origin.y += frame.height - size.height // keep bottom edge
        frame.size = size
        panel.setFrame(frame, display: false)

        effectView.frame = NSRect(origin: .zero, size: size)
        hostingView.frame = effectView.bounds
        effectView.layer?.cornerRadius = size.height / 2
        effectView.layer?.masksToBounds = true
    }

    private func bottomOfScreenOrigin() -> NSPoint {
        guard let screen = NSScreen.main else { return .zero }
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.minY + 18
        return NSPoint(x: x, y: y)
    }
}
