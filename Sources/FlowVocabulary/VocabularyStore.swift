import Foundation

@MainActor
public final class VocabularyStore: ObservableObject {
    @Published public private(set) var terms: [VocabularyTerm] = []

    private let fileURL: URL

    public init() {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Flow", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        self.fileURL = supportDir.appendingPathComponent("vocabulary.json")
        self.terms = Self.load(from: fileURL)
    }

    public func add(term: String, note: String? = nil) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !terms.contains(where: { $0.term.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        terms.append(VocabularyTerm(term: trimmed, note: note))
        save()
    }

    public func remove(id: UUID) {
        terms.removeAll { $0.id == id }
        save()
    }

    public var initialPromptText: String? {
        guard !terms.isEmpty else { return nil }
        let names = terms.map(\.term).joined(separator: ", ")
        return "Terms that may appear: \(names)."
    }

    private static func load(from url: URL) -> [VocabularyTerm] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([VocabularyTerm].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(terms) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
