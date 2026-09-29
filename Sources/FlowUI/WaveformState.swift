import Foundation

@MainActor
public final class WaveformState: ObservableObject {
    @Published public var currentLevel: Float = 0
    @Published public var isLocked: Bool = false
    @Published public var profileName: String = "Writing"
    // shown instead of the bars
    @Published public var message: String?

    public init() {}

    // db scale (-50 floor), linear clipped too easily. fast attack slow release
    public func pushLevel(_ rawLevel: Float) {
        let decibels = 20 * log10(max(rawLevel, 1e-5))
        let target = max(0, min(1, (decibels + 50) / 50))
        let blend: Float = target > currentLevel ? 0.85 : 0.4
        currentLevel += (target - currentLevel) * blend
    }

    public func reset() {
        currentLevel = 0
        isLocked = false
        message = nil
    }
}
