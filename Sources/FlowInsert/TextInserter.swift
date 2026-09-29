import AppKit
@preconcurrency import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics

public enum TextInsertionError: Error {
    case secureInputActive
}

// order: AX -> paste -> keystrokes
@MainActor
public enum TextInserter {

    public static func insert(_ text: String) throws {
        guard !text.isEmpty else { return }
        guard !isSecureInputActive() else { throw TextInsertionError.secureInputActive }

        if insertViaAccessibility(text) { return }
        if insertViaPaste(text) { return }
        insertViaKeystrokes(text)
    }

    // MARK: - AX

    // electron reports success and does nothing, so read value back
    private static func insertViaAccessibility(_ text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focused = focusedRef else {
            return false
        }
        let element = focused as! AXUIElement

        var previousValueRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &previousValueRef)
        let previousValue = previousValueRef as? String

        let setResult = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        guard setResult == .success else { return false }

        var newValueRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &newValueRef)
        let newValue = newValueRef as? String

        // no readback (secure fields) -> trust success
        guard let newValue else { return true }
        return newValue != previousValue
    }

    // MARK: - Clipboard paste

    private static func insertViaPaste(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        let savedItems = pasteboard.pasteboardItems?.compactMap { item -> [String: Data] in
            var representations: [String: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    representations[type.rawValue] = data
                }
            }
            return representations
        }
        let savedChangeCount = pasteboard.changeCount

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard postCmdV() else { return false }

        // restore unless something else wrote to it
        let restoreDelay: TimeInterval = 0.4
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
            guard pasteboard.changeCount == savedChangeCount + 1 else { return }
            pasteboard.clearContents()
            guard let savedItems else { return }
            for representations in savedItems {
                let item = NSPasteboardItem()
                for (typeRawValue, data) in representations {
                    item.setData(data, forType: NSPasteboard.PasteboardType(typeRawValue))
                }
                pasteboard.writeObjects([item])
            }
        }
        return true
    }

    private static func postCmdV() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return false }
        let vKeyCode = CGKeyCode(kVK_ANSI_V)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return false
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    // MARK: - Keystroke simulation (last resort)

    // unicode string caps at 20 utf16 units, chunk it
    private static func insertViaKeystrokes(_ text: String) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let utf16 = Array(text.utf16)
        let chunkSize = 20
        var index = 0

        while index < utf16.count {
            var end = min(index + chunkSize, utf16.count)
            // don't split surrogate pairs
            if end < utf16.count, UTF16.isLeadSurrogate(utf16[end - 1]) {
                end -= 1
            }

            let chunk = Array(utf16[index..<end])
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                keyDown.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
                keyDown.post(tap: .cghidEventTap)
            }
            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                keyUp.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
                keyUp.post(tap: .cghidEventTap)
            }
            index = end
            Thread.sleep(forTimeInterval: 0.005)
        }
    }

    // MARK: - Secure input

    private static func isSecureInputActive() -> Bool {
        IsSecureEventInputEnabled()
    }
}
