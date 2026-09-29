import FlowProfiles

public enum PostProcessingError: Error {
    case apiError(statusCode: Int, message: String)
    case emptyResponse
    case missingAPIKey
    case invalidAPIKey
    // hit output limit, caller uses raw text
    case truncated
    case refused
}

public protocol PostProcessingBackend: Sendable {
    func process(transcript: String, profile: Profile, vocabulary: [String]) async throws -> String
}
