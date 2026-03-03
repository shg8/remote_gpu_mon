import Foundation

final class HistoryStore {
    private let directory: URL

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        directory = appSupport.appendingPathComponent("GPUMonitor")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func load(for nodeId: UUID, retentionInterval: TimeInterval) -> [HistoryPoint] {
        let url = fileURL(for: nodeId)
        guard let data = try? Data(contentsOf: url) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        guard let persisted = try? decoder.decode(PersistedHistory.self, from: data) else {
            print("[GPUMon] HistoryStore: corrupt history file for \(nodeId), ignoring")
            return []
        }

        let cutoff = Date().addingTimeInterval(-retentionInterval)
        return persisted.points.filter { $0.timestamp >= cutoff }
    }

    func save(_ points: [HistoryPoint], for nodeId: UUID) {
        let persisted = PersistedHistory(version: PersistedHistory.currentVersion, points: points)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970

        guard let data = try? encoder.encode(persisted) else { return }
        try? data.write(to: fileURL(for: nodeId), options: .atomic)
    }

    func delete(for nodeId: UUID) {
        try? FileManager.default.removeItem(at: fileURL(for: nodeId))
    }

    private func fileURL(for nodeId: UUID) -> URL {
        directory.appendingPathComponent("history-\(nodeId.uuidString).json")
    }
}
