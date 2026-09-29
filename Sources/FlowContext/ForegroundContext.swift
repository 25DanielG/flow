import AppKit
import ApplicationServices

public struct ForegroundApp: Sendable {
    public let pid: pid_t
    public let bundleID: String?
    public let name: String?
}

public struct ForegroundContext: Sendable, Equatable {
    public var bundleID: String?
    public var appName: String?
    public var windowTitle: String?
    // chrome only shows the host by default
    public var urlText: String?

    // nil if not a site (spaces / no dot)
    public var siteHost: String? {
        guard var text = urlText?.lowercased(), !text.isEmpty else { return nil }
        if let scheme = text.range(of: "://") { text = String(text[scheme.upperBound...]) }
        guard let host = text.split(separator: "/").first.map(String.init),
              host.contains("."), !host.contains(" ")
        else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    public init(bundleID: String? = nil, appName: String? = nil, windowTitle: String? = nil, urlText: String? = nil) {
        self.bundleID = bundleID
        self.appName = appName
        self.windowTitle = windowTitle
        self.urlText = urlText
    }
}

public enum ForegroundContextReader {
    private static let browserBundleIDs: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary",
        "com.apple.Safari", "com.apple.SafariTechnologyPreview",
        "company.thebrowser.Browser", // Arc
        "com.brave.Browser", "com.microsoft.edgemac", "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera", "org.mozilla.firefox"
    ]

    // main thread, do this first then context(for:) in bg
    @MainActor
    public static func currentApp() -> ForegroundApp? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return ForegroundApp(pid: app.processIdentifier, bundleID: app.bundleIdentifier, name: app.localizedName)
    }

    public static func context(for app: ForegroundApp?) -> ForegroundContext {
        guard let app else { return ForegroundContext() }
        var context = ForegroundContext(bundleID: app.bundleID, appName: app.name)
        guard AXIsProcessTrusted() else { return context }

        let element = AXUIElementCreateApplication(app.pid)
        // default timeout is seconds
        AXUIElementSetMessagingTimeout(element, 0.3)
        guard let window = elementAttribute(element, kAXFocusedWindowAttribute) else { return context }
        context.windowTitle = stringAttribute(window, kAXTitleAttribute)

        if let bundleID = app.bundleID, browserBundleIDs.contains(bundleID) {
            context.urlText = findAddressBarText(in: window)
            if context.urlText == nil {
                // chromium builds AX tree lazily, only poke it if first pass failed
                AXUIElementSetAttributeValue(element, "AXManualAccessibility" as CFString, kCFBooleanTrue)
                Thread.sleep(forTimeInterval: 0.15)
                context.urlText = findAddressBarText(in: window)
            }
        }
        return context
    }

    // bfs, address bar is near the top (~70 nodes)
    private static func findAddressBarText(in window: AXUIElement) -> String? {
        var queue: [(AXUIElement, Int)] = [(window, 0)]
        var index = 0
        var webAreaURL: String?
        while index < queue.count, index < 2500 {
            let (element, depth) = queue[index]
            index += 1
            let role = stringAttribute(element, kAXRoleAttribute)
            if role == "AXTextField" || role == "AXComboBox" {
                let description = (stringAttribute(element, kAXDescriptionAttribute) ?? "").lowercased()
                if ["address", "url", "search bar", "smart search"].contains(where: description.contains),
                   let value = stringAttribute(element, kAXValueAttribute), !value.isEmpty {
                    return value
                }
            } else if role == "AXWebArea", webAreaURL == nil {
                var raw: CFTypeRef?
                AXUIElementCopyAttributeValue(element, "AXURL" as CFString, &raw)
                webAreaURL = (raw as? URL)?.absoluteString
            }
            if depth < 12, let children = childrenAttribute(element) {
                for child in children { queue.append((child, depth + 1)) }
            }
        }
        return webAreaURL
    }

    private static func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func elementAttribute(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }

    private static func childrenAttribute(_ element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success else { return nil }
        return value as? [AXUIElement]
    }
}
