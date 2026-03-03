import Foundation

struct GPUMetrics: Sendable {
    let index: Int
    let name: String
    let busId: String
    let utilizationPercent: Int
    let memoryUsedMB: Int
    let memoryTotalMB: Int
    let temperatureC: Int

    var memoryPercent: Double {
        guard memoryTotalMB > 0 else { return 0 }
        return Double(memoryUsedMB) / Double(memoryTotalMB) * 100
    }
}

struct GPUProcess: Sendable {
    let pid: Int
    let processName: String
    let gpuMemoryMB: Int
    let gpuIndex: Int
    let user: String
}

struct NodeSnapshot: Sendable {
    let nodeId: UUID
    let timestamp: Date
    let gpus: [GPUMetrics]
    let processes: [GPUProcess]
    let error: String?
}

struct NodeState {
    var node: GPUNode
    var isOnline: Bool = false
    var latestSnapshot: NodeSnapshot?
    var history: [NodeSnapshot] = []
}

// MARK: - Persistence Types

struct GPUSnap: Codable, Sendable {
    let index: Int
    let name: String
    let utilizationPercent: Int
    let memoryUsedMB: Int
    let memoryTotalMB: Int
    let temperatureC: Int
}

struct HistoryPoint: Codable, Sendable {
    let timestamp: Date
    let gpus: [GPUSnap]

    init(from snapshot: NodeSnapshot) {
        self.timestamp = snapshot.timestamp
        self.gpus = snapshot.gpus.map { gpu in
            GPUSnap(
                index: gpu.index,
                name: gpu.name,
                utilizationPercent: gpu.utilizationPercent,
                memoryUsedMB: gpu.memoryUsedMB,
                memoryTotalMB: gpu.memoryTotalMB,
                temperatureC: gpu.temperatureC
            )
        }
    }

    func toNodeSnapshot(nodeId: UUID) -> NodeSnapshot {
        NodeSnapshot(
            nodeId: nodeId,
            timestamp: timestamp,
            gpus: gpus.map { snap in
                GPUMetrics(
                    index: snap.index,
                    name: snap.name,
                    busId: "",
                    utilizationPercent: snap.utilizationPercent,
                    memoryUsedMB: snap.memoryUsedMB,
                    memoryTotalMB: snap.memoryTotalMB,
                    temperatureC: snap.temperatureC
                )
            },
            processes: [],
            error: nil
        )
    }
}

struct PersistedHistory: Codable, Sendable {
    let version: Int
    let points: [HistoryPoint]

    static let currentVersion = 1
}
