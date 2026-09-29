import CWhisper
import Foundation

public enum WhisperError: Error {
    case failedToLoadModel(path: String)
}

private func withOptionalCString<Result>(_ string: String?, _ body: (UnsafePointer<CChar>?) -> Result) -> Result {
    guard let string else { return body(nil) }
    return string.withCString(body)
}

// actor since whisper_context isn't thread safe
// coreml used if <model>-encoder.mlmodelc is next to the .bin
public actor WhisperContext {
    // deinit is nonisolated
    private nonisolated(unsafe) let context: OpaquePointer

    public init(modelPath: String) throws {
        var params = whisper_context_default_params()
        params.use_gpu = true
        guard let ctx = whisper_init_from_file_with_params(modelPath, params) else {
            throw WhisperError.failedToLoadModel(path: modelPath)
        }
        self.context = ctx
    }

    deinit {
        whisper_free(context)
    }

    public func transcribe(samples: [Float], language: String = "en", initialPrompt: String? = nil) -> String {
        guard !samples.isEmpty else { return "" }

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_progress = false
        params.print_special = false
        params.print_realtime = false
        params.print_timestamps = false
        params.translate = false
        params.no_context = true
        params.single_segment = false
        params.no_timestamps = true
        params.suppress_blank = true
        params.n_threads = Int32(max(1, min(8, ProcessInfo.processInfo.activeProcessorCount - 2)))

        let context = self.context
        let status: Int32 = language.withCString { languagePtr in
            params.language = languagePtr
            return withOptionalCString(initialPrompt) { promptPtr in
                params.initial_prompt = promptPtr
                return samples.withUnsafeBufferPointer { buffer in
                    whisper_full(context, params, buffer.baseAddress, Int32(buffer.count))
                }
            }
        }
        guard status == 0 else { return "" }

        var text = ""
        let segmentCount = whisper_full_n_segments(context)
        for i in 0..<segmentCount {
            if let segmentText = whisper_full_get_segment_text(context, i) {
                text += String(cString: segmentText)
            }
        }
        return Self.stripNonSpeechTags(text)
    }

    // strips [BLANK_AUDIO], (music) etc. suppress_nst breaks "3:30" so regex instead
    static func stripNonSpeechTags(_ text: String) -> String {
        var result = text.replacingOccurrences(
            of: #"\[[^\]\n]{1,40}\]"#, with: " ", options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\((?:[a-z ]{0,20})(?:music|silence|noise|applause|laughter|inaudible)[a-z ]{0,20}\)"#,
            with: " ", options: [.regularExpression, .caseInsensitive]
        )
        return result
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
