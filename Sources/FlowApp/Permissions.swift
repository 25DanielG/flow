import AppKit
import AVFoundation
@preconcurrency import ApplicationServices
import CoreGraphics
import Foundation

enum PermissionKind: String, CaseIterable {
    case microphone = "Microphone"
    case accessibility = "Accessibility"
    case inputMonitoring = "Input Monitoring"

    var explanation: String {
        switch self {
        case .microphone:
            return "Needed to capture your voice while dictating."
        case .accessibility:
            return "Needed to insert text into the focused field and to simulate keystrokes/paste as a fallback."
        case .inputMonitoring:
            return "Needed to detect the FN/Globe key globally, even when Flow isn't the frontmost app."
        }
    }

    // undocumented url schemes, they change between macOS versions
    var settingsURL: URL? {
        switch self {
        case .microphone:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        case .accessibility:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .inputMonitoring:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
        }
    }
}

enum PermissionStatus {
    case granted
    case denied
}

@MainActor
final class PermissionsManager {

    func status(for kind: PermissionKind) -> PermissionStatus {
        switch kind {
        case .microphone:
            return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized ? .granted : .denied
        case .accessibility:
            return AXIsProcessTrusted() ? .granted : .denied
        case .inputMonitoring:
            return CGPreflightListenEventAccess() ? .granted : .denied
        }
    }

    var allGranted: Bool {
        PermissionKind.allCases.allSatisfy { status(for: $0) == .granted }
    }

    func request(_ kind: PermissionKind, completion: @escaping @MainActor @Sendable (PermissionStatus) -> Void) {
        switch kind {
        case .microphone:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                Task { @MainActor in completion(granted ? .granted : .denied) }
            }
        case .accessibility:
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            let trusted = AXIsProcessTrustedWithOptions(options)
            completion(trusted ? .granted : .denied)
        case .inputMonitoring:
            let granted = CGRequestListenEventAccess()
            completion(granted ? .granted : .denied)
        }
    }

    func openSettings(for kind: PermissionKind) {
        guard let url = kind.settingsURL else { return }
        NSWorkspace.shared.open(url)
    }
}
