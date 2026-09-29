import Foundation

public struct VocabularyTerm: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var term: String
    public var note: String?

    public init(id: UUID = UUID(), term: String, note: String? = nil) {
        self.id = id
        self.term = term
        self.note = note
    }
}
