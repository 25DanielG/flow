import Foundation

public enum DictationTriggerEffect: Equatable {
    case startRecording
    case promoteToLocked
    case stopAndTranscribe
    case discardRecording
    case scheduleTimeout(after: TimeInterval, token: Int)
}

public struct DictationTriggerConfig {
    public var doubleTapWindow: TimeInterval

    public init(doubleTapWindow: TimeInterval = 0.35) {
        self.doubleTapWindow = doubleTapWindow
    }
}

// hold to talk / double tap to lock. no clock in here, driver fires handleTimeout with the token
// quick release waits out the window, 2nd down = lock, otherwise discard
public final class DictationTriggerStateMachine {
    private enum State {
        case idle
        case heldWaitingForWindow(generation: Int)
        case heldConfirmed
        case pendingSecondTap(generation: Int)
        case locked
        case lockedStopping
    }

    private let config: DictationTriggerConfig
    private var state: State = .idle
    private var generationCounter = 0

    public init(config: DictationTriggerConfig = DictationTriggerConfig()) {
        self.config = config
    }

    @discardableResult
    public func handleKeyDown() -> [DictationTriggerEffect] {
        switch state {
        case .idle:
            generationCounter += 1
            let generation = generationCounter
            state = .heldWaitingForWindow(generation: generation)
            return [.startRecording, .scheduleTimeout(after: config.doubleTapWindow, token: generation)]
        case .pendingSecondTap:
            state = .locked
            return [.promoteToLocked]
        case .locked:
            state = .lockedStopping
            return []
        case .heldWaitingForWindow, .heldConfirmed, .lockedStopping:
            // duplicate down, ignore
            return []
        }
    }

    @discardableResult
    public func handleKeyUp() -> [DictationTriggerEffect] {
        switch state {
        case .heldWaitingForWindow(let generation):
            state = .pendingSecondTap(generation: generation)
            return []
        case .heldConfirmed:
            state = .idle
            return [.stopAndTranscribe]
        case .lockedStopping:
            state = .idle
            return [.stopAndTranscribe]
        case .idle, .pendingSecondTap, .locked:
            return []
        }
    }

    @discardableResult
    public func handleTimeout(token: Int) -> [DictationTriggerEffect] {
        switch state {
        case .heldWaitingForWindow(let generation) where generation == token:
            state = .heldConfirmed
            return []
        case .pendingSecondTap(let generation) where generation == token:
            state = .idle
            return [.discardRecording]
        default:
            // stale
            return []
        }
    }

    @discardableResult
    public func cancel() -> [DictationTriggerEffect] {
        guard case .idle = state else {
            state = .idle
            return [.discardRecording]
        }
        return []
    }
}
