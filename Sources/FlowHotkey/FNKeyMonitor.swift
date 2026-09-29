import AppKit
import CoreGraphics
import Foundation

public protocol FNKeyMonitorDelegate: AnyObject {
    @MainActor func fnKeyMonitor(_ monitor: FNKeyMonitor, didProduce effect: DictationTriggerEffect)
}

// from Carbon, hardcoded so we don't import it
private let kVKFunctionKeyCode: Int64 = 0x3F
private let kVKEscapeKeyCode: Int64 = 0x35

// fn comes as flagsChanged, mask is also set for arrows/F keys so filter on keycode 63
// tapCreate returns nil w/o input monitoring, call start() again after grant
@MainActor
public final class FNKeyMonitor {
    public weak var delegate: FNKeyMonitorDelegate?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let stateMachine: DictationTriggerStateMachine
    private var pendingTimeouts: [Int: DispatchWorkItem] = [:]

    public init(config: DictationTriggerConfig = DictationTriggerConfig()) {
        self.stateMachine = DictationTriggerStateMachine(config: config)
    }

    @discardableResult
    public func start() -> Bool {
        guard eventTap == nil else { return true }

        // keyDown only for esc-to-cancel
        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue) | CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<FNKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                // source is on main run loop
                MainActor.assumeIsolated {
                    monitor.handle(type: type, event: event)
                }
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleWake), name: NSWorkspace.didWakeNotification, object: nil
        )
        return true
    }

    public func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        for item in pendingTimeouts.values { item.cancel() }
        pendingTimeouts.removeAll()
        NotificationCenter.default.removeObserver(self, name: NSWorkspace.didWakeNotification, object: nil)
    }

    @objc private func handleWake() {
        // system kills the tap during sleep
        stop()
        _ = start()
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if type == .keyDown {
            guard keyCode == kVKEscapeKeyCode else { return }
            process(stateMachine.cancel())
            return
        }

        guard type == .flagsChanged, keyCode == kVKFunctionKeyCode else { return }
        let isDown = event.flags.contains(.maskSecondaryFn)
        let effects = isDown ? stateMachine.handleKeyDown() : stateMachine.handleKeyUp()
        process(effects)
    }

    private func process(_ effects: [DictationTriggerEffect]) {
        for effect in effects {
            switch effect {
            case .scheduleTimeout(let after, let token):
                let workItem = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.pendingTimeouts[token] = nil
                    self.process(self.stateMachine.handleTimeout(token: token))
                }
                pendingTimeouts[token] = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + after, execute: workItem)
            default:
                delegate?.fnKeyMonitor(self, didProduce: effect)
            }
        }
    }
}
