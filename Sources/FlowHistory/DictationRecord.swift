import Foundation

public struct DictationRecord: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var timestamp: Date
    public var rawText: String
    public var finalText: String
    public var profileName: String
    public var audioDuration: TimeInterval
    public var wasPostProcessed: Bool
    // optional for old history files
    public var appBundleID: String?
    public var appName: String?
    public var siteHost: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        rawText: String,
        finalText: String,
        profileName: String,
        audioDuration: TimeInterval,
        wasPostProcessed: Bool,
        appBundleID: String? = nil,
        appName: String? = nil,
        siteHost: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.rawText = rawText
        self.finalText = finalText
        self.profileName = profileName
        self.audioDuration = audioDuration
        self.wasPostProcessed = wasPostProcessed
        self.appBundleID = appBundleID
        self.appName = appName
        self.siteHost = siteHost
    }
}
