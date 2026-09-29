import Testing
@testable import FlowHotkey

@Suite
struct DictationTriggerStateMachineTests {

    @Test
    func plainHoldStartsRecordingAndStopsOnRelease() {
        let sm = DictationTriggerStateMachine()

        let downEffects = sm.handleKeyDown()
        #expect(downEffects.contains(.startRecording))
        guard case .scheduleTimeout(_, let token) = downEffects.last(where: {
            if case .scheduleTimeout = $0 { return true }
            return false
        })! else {
            Issue.record("expected a scheduleTimeout effect")
            return
        }

        #expect(sm.handleTimeout(token: token).isEmpty)

        #expect(sm.handleKeyUp() == [.stopAndTranscribe])
    }

    @Test
    func quickTapWithNoSecondTapIsDiscardedAfterWindow() {
        let sm = DictationTriggerStateMachine()

        let downEffects = sm.handleKeyDown()
        let token = downEffects.compactMap { effect -> Int? in
            if case .scheduleTimeout(_, let token) = effect { return token }
            return nil
        }.first!

        #expect(sm.handleKeyUp().isEmpty)

        // no second tap
        #expect(sm.handleTimeout(token: token) == [.discardRecording])
    }

    @Test
    func doubleTapWithinWindowLocksAndIgnoresInterveningRelease() {
        let sm = DictationTriggerStateMachine()

        _ = sm.handleKeyDown()
        #expect(sm.handleKeyUp().isEmpty)

        #expect(sm.handleKeyDown() == [.promoteToLocked])

        #expect(sm.handleKeyDown().isEmpty)
        #expect(sm.handleKeyUp() == [.stopAndTranscribe])
    }

    @Test
    func staleTimeoutAfterStateMovedOnIsIgnored() {
        let sm = DictationTriggerStateMachine()

        let downEffects = sm.handleKeyDown()
        let staleToken = downEffects.compactMap { effect -> Int? in
            if case .scheduleTimeout(_, let token) = effect { return token }
            return nil
        }.first!

        _ = sm.handleTimeout(token: staleToken)
        #expect(sm.handleKeyUp() == [.stopAndTranscribe])

        let secondDownEffects = sm.handleKeyDown()
        #expect(secondDownEffects.contains(.startRecording))

        // old token shouldn't touch the new session
        #expect(sm.handleTimeout(token: staleToken).isEmpty)
    }

    @Test
    func duplicateDownWithoutInterveningUpIsIgnored() {
        let sm = DictationTriggerStateMachine()
        _ = sm.handleKeyDown()
        #expect(sm.handleKeyDown().isEmpty)
    }

    @Test
    func strayUpWithoutPrecedingDownIsIgnored() {
        let sm = DictationTriggerStateMachine()
        #expect(sm.handleKeyUp().isEmpty)
    }

    @Test
    func cancelDuringActiveRecordingDiscards() {
        let sm = DictationTriggerStateMachine()
        _ = sm.handleKeyDown()
        #expect(sm.cancel() == [.discardRecording])
        #expect(sm.handleKeyUp().isEmpty)
    }

    @Test
    func cancelWhileLockedDiscards() {
        let sm = DictationTriggerStateMachine()
        _ = sm.handleKeyDown()
        _ = sm.handleKeyUp()
        _ = sm.handleKeyDown()
        #expect(sm.cancel() == [.discardRecording])
    }

    @Test
    func cancelWhileIdleIsNoOp() {
        let sm = DictationTriggerStateMachine()
        #expect(sm.cancel().isEmpty)
    }
}
