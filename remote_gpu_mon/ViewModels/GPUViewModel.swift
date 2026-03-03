import Foundation
import Observation
import ServiceManagement

@Observable
final class GPUViewModel {
    // MARK: - State

    var nodeStates: [UUID: NodeState] = [:]
    var activeNodeId: UUID?

    // MARK: - Settings

    var pollingInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(pollingInterval, forKey: "pollingInterval")
            restartAllPolling()
        }
    }

    var chartTimeWindowMinutes: Int {
        didSet { UserDefaults.standard.set(chartTimeWindowMinutes, forKey: "chartTimeWindowMinutes") }
    }

    var dataRetentionHours: Int {
        didSet {
            UserDefaults.standard.set(dataRetentionHours, forKey: "dataRetentionHours")
            trimAndSaveAllHistory()
        }
    }

    var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            updateLoginItem()
        }
    }

    // MARK: - Callbacks

    var onUpdate: (() -> Void)?

    // MARK: - Computed

    var sortedNodeStates: [NodeState] {
        nodeStates.values.sorted {
            $0.node.displayName.localizedCaseInsensitiveCompare($1.node.displayName) == .orderedAscending
        }
    }

    var activeNodeState: NodeState? {
        guard let id = activeNodeId else { return nil }
        return nodeStates[id]
    }

    // MARK: - Private

    private let sshService = SSHService()
    private let parser = NvidiaSMIParser()
    private let nodeStore = NodeStore()
    private let historyStore = HistoryStore()
    private var pollingTasks: [UUID: Task<Void, Never>] = [:]

    // MARK: - Init

    init() {
        pollingInterval = UserDefaults.standard.object(forKey: "pollingInterval") as? TimeInterval ?? 15
        chartTimeWindowMinutes = UserDefaults.standard.object(forKey: "chartTimeWindowMinutes") as? Int ?? 30
        dataRetentionHours = UserDefaults.standard.object(forKey: "dataRetentionHours") as? Int ?? 24
        launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
    }

    // MARK: - Node Management

    func loadNodes() {
        let nodes = nodeStore.load()
        for node in nodes {
            if nodeStates[node.id] == nil {
                nodeStates[node.id] = NodeState(node: node)
            }
        }
        if activeNodeId == nil {
            activeNodeId = nodes.first?.id
        }
        loadAllHistory()
    }

    func addNode(_ node: GPUNode) {
        nodeStates[node.id] = NodeState(node: node)
        if activeNodeId == nil {
            activeNodeId = node.id
        }
        saveNodes()
        startPolling(for: node.id)
    }

    func updateNode(_ node: GPUNode) {
        nodeStates[node.id]?.node = node
        saveNodes()
    }

    func removeNode(_ id: UUID) {
        stopPolling(for: id)
        nodeStates.removeValue(forKey: id)
        KeychainHelper.deletePassword(for: id)
        historyStore.delete(for: id)
        if activeNodeId == id {
            activeNodeId = nodeStates.keys.first
        }
        saveNodes()
    }

    func setActiveNode(_ id: UUID) {
        activeNodeId = id
        onUpdate?()
    }

    // MARK: - Polling

    func startAllPolling() {
        for id in nodeStates.keys {
            startPolling(for: id)
        }
    }

    func stopAllPolling() {
        for (_, task) in pollingTasks {
            task.cancel()
        }
        pollingTasks.removeAll()
    }

    func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            for id in nodeStates.keys {
                group.addTask { await self.pollNode(id) }
            }
        }
    }

    func refreshNode(_ id: UUID) async {
        await pollNode(id)
    }

    // MARK: - Test Connection

    func testConnection(host: String, port: Int?, auth: SSHAuth) async throws -> String {
        try await sshService.execute(
            host: host,
            port: port,
            auth: auth,
            command: "echo OK && nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo 'nvidia-smi not found'"
        )
    }

    // MARK: - Private

    private func startPolling(for nodeId: UUID) {
        pollingTasks[nodeId]?.cancel()
        pollingTasks[nodeId] = Task {
            while !Task.isCancelled {
                await pollNode(nodeId)
                try? await Task.sleep(for: .seconds(pollingInterval))
            }
        }
    }

    private func stopPolling(for nodeId: UUID) {
        pollingTasks[nodeId]?.cancel()
        pollingTasks.removeValue(forKey: nodeId)
    }

    private func restartAllPolling() {
        stopAllPolling()
        startAllPolling()
    }

    func pollNode(_ nodeId: UUID) async {
        guard let state = nodeStates[nodeId] else {
            print("[GPUMon] pollNode: nodeId \(nodeId) not found in nodeStates")
            return
        }
        let node = state.node
        print("[GPUMon] pollNode: polling \(node.displayName) (\(node.hostname))")

        do {
            let auth = buildAuth(for: node)
            let output = try await sshService.execute(
                host: node.hostname,
                port: node.port,
                auth: auth,
                command: parser.command
            )

            print("[GPUMon] pollNode: SSH output length=\(output.count), first 200 chars: \(String(output.prefix(200)))")

            let parsed = parser.parse(output: output)
            print("[GPUMon] pollNode: parsed \(parsed.gpus.count) GPUs, \(parsed.processes.count) processes")

            let snapshot = NodeSnapshot(
                nodeId: nodeId,
                timestamp: Date(),
                gpus: parsed.gpus,
                processes: parsed.processes,
                error: nil
            )

            nodeStates[nodeId]?.isOnline = true
            nodeStates[nodeId]?.latestSnapshot = snapshot
            nodeStates[nodeId]?.history.append(snapshot)
            trimHistory(for: nodeId)
            saveHistory(for: nodeId)
        } catch {
            print("[GPUMon] pollNode: ERROR for \(node.displayName): \(error)")
            nodeStates[nodeId]?.isOnline = false
            nodeStates[nodeId]?.latestSnapshot = NodeSnapshot(
                nodeId: nodeId,
                timestamp: Date(),
                gpus: [],
                processes: [],
                error: error.localizedDescription
            )
        }

        onUpdate?()
    }

    private func buildAuth(for node: GPUNode) -> SSHAuth {
        switch node.authMethod {
        case .sshConfig:
            return .defaultConfig
        case .keyFile(let path):
            return .keyFile(path)
        case .password:
            let pwd = KeychainHelper.getPassword(for: node.id) ?? ""
            return .password(pwd)
        }
    }

    private func trimHistory(for nodeId: UUID) {
        let cutoff = Date().addingTimeInterval(-Double(dataRetentionHours) * 3600)
        nodeStates[nodeId]?.history.removeAll { $0.timestamp < cutoff }
    }

    private func loadAllHistory() {
        let retention = TimeInterval(dataRetentionHours) * 3600
        for (id, _) in nodeStates {
            let points = historyStore.load(for: id, retentionInterval: retention)
            nodeStates[id]?.history = points.map { $0.toNodeSnapshot(nodeId: id) }
        }
    }

    private func saveHistory(for nodeId: UUID) {
        guard let history = nodeStates[nodeId]?.history else { return }
        let points = history.map { HistoryPoint(from: $0) }
        historyStore.save(points, for: nodeId)
    }

    func saveAllHistory() {
        for id in nodeStates.keys {
            saveHistory(for: id)
        }
    }

    private func trimAndSaveAllHistory() {
        for id in nodeStates.keys {
            trimHistory(for: id)
            saveHistory(for: id)
        }
    }

    private func saveNodes() {
        let nodes = nodeStates.values.map(\.node)
        nodeStore.save(Array(nodes))
    }

    private func updateLoginItem() {
        if launchAtLogin {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }
}
