import Foundation

final class NodeStore {
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let appDir = appSupport.appendingPathComponent("GPUMonitor")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        fileURL = appDir.appendingPathComponent("nodes.json")
    }

    func load() -> [GPUNode] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([GPUNode].self, from: data)) ?? []
    }

    func save(_ nodes: [GPUNode]) {
        guard let data = try? JSONEncoder().encode(nodes) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
