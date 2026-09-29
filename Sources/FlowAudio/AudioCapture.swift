import AVFoundation

public enum AudioCaptureError: Error {
    case formatCreationFailed
    case converterCreationFailed
}

private actor SampleStore {
    private var samples: [Float] = []

    func append(_ newSamples: [Float]) {
        samples.append(contentsOf: newSamples)
    }

    func drain() -> [Float] {
        defer { samples.removeAll(keepingCapacity: true) }
        return samples
    }
}

// free func on purpose, inline closure inherits @MainActor and spams data race warnings
private func makeTapBlock(
    converter: AVAudioConverter,
    targetFormat: AVAudioFormat,
    store: SampleStore,
    onLevel: @escaping @MainActor @Sendable (Float) -> Void
) -> @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void {
    { buffer, _ in
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputCapacity) else {
            return
        }

        var consumed = false
        let status = converter.convert(to: outputBuffer, error: nil) { _, inputStatus in
            if consumed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            inputStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, let channelData = outputBuffer.floatChannelData else { return }

        let frameCount = Int(outputBuffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
        let peak = samples.reduce(into: Float(0)) { $0 = max($0, abs($1)) }

        Task { await store.append(samples) }
        Task { @MainActor in onLevel(min(peak, 1.0)) }
    }
}

@MainActor
public final class AudioCapture {
    // new engine per session, reused one gets stale format after route change -> objc exception
    private var engine: AVAudioEngine?
    private let store = SampleStore()
    private var isRunning = false

    public init() {}

    public var targetSampleRate: Double { 16_000 }

    public func start(onLevel: @escaping @MainActor @Sendable (Float) -> Void) throws {
        guard !isRunning else { return }

        let engine = AVAudioEngine()
        self.engine = engine
        let inputNode = engine.inputNode
        // before reading format
        let selection = MicrophonePreference.resolve()
        if let device = selection.device {
            do {
                try inputNode.auAudioUnit.setDeviceID(device.id)
            } catch {
                print("Flow: couldn't select microphone '\(device.name)' (\(error)) — using system default")
            }
        }
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            self.engine = nil
            throw AudioCaptureError.formatCreationFailed
        }
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            self.engine = nil
            throw AudioCaptureError.converterCreationFailed
        }

        let tapBlock = makeTapBlock(converter: converter, targetFormat: targetFormat, store: store, onLevel: onLevel)
        inputNode.installTap(onBus: 0, bufferSize: 512, format: inputFormat, block: tapBlock)

        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            self.engine = nil
            throw error
        }
        isRunning = true
        print("Flow: recording from '\(selection.device?.name ?? AudioInputDevices.defaultInput()?.name ?? "default")' (\(selection.reason)), \(Int(inputFormat.sampleRate))Hz x\(inputFormat.channelCount)")
    }

    public func stop() async -> [Float] {
        guard isRunning, let engine else { return [] }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
        isRunning = false
        return await store.drain()
    }

    public func discard() async {
        _ = await stop()
    }
}
