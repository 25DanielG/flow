import Foundation

@MainActor
public final class HistoryStore: ObservableObject {
    public static let maxRecords = 1000

    @Published public private(set) var records: [DictationRecord] = []

    private let fileURL: URL

    public init() {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Flow", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        self.fileURL = supportDir.appendingPathComponent("history.json")
        self.records = Self.load(from: fileURL)
    }

    public func record(_ record: DictationRecord) {
        records.insert(record, at: 0)
        if records.count > Self.maxRecords {
            records.removeLast(records.count - Self.maxRecords)
        }
        save()
    }

    public func clear() {
        records.removeAll()
        save()
    }

    private static func load(from url: URL) -> [DictationRecord] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([DictationRecord].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
