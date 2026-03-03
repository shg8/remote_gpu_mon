import SwiftUI

struct NodeSection: View {
    let state: NodeState
    let isActive: Bool
    let chartTimeWindow: TimeInterval
    let onSelect: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // Header
            HStack {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(state.node.displayName)
                        .font(.system(size: 13, weight: isActive ? .bold : .regular))

                    if !state.isOnline {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 10))
                            .foregroundStyle(.red)
                    }
                }

                Spacer()

                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            // GPU rows
            if state.isOnline, let snapshot = state.latestSnapshot {
                if snapshot.gpus.isEmpty {
                    Text(snapshot.error ?? "No GPUs detected")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        } else {
                    ForEach(gpuIndices, id: \.self) { gpuIndex in
                        GPURow(
                            gpuIndex: gpuIndex,
                            history: historyForGPU(gpuIndex),
                            processes: processesForGPU(gpuIndex, in: snapshot),
                            timeWindow: chartTimeWindow
                        )
                    }
                }
            } else if !state.isOnline {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                    Text(state.latestSnapshot?.error ?? "Offline")
                        .lineLimit(2)
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            } else {
                HStack(spacing: Theme.Spacing.xs) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Connecting...")
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
        }
        .padding(Theme.Card.padding)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .background {
            RoundedRectangle(cornerRadius: Theme.Card.cornerRadius)
                .fill(isActive ? Color.accentColor.opacity(Theme.Card.activeOpacity) : Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .overlay(alignment: .leading) {
                    if isActive {
                        UnevenRoundedRectangle(
                            topLeadingRadius: Theme.Card.cornerRadius,
                            bottomLeadingRadius: Theme.Card.cornerRadius
                        )
                        .fill(Color.accentColor)
                        .frame(width: 3)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.Card.cornerRadius))
        }
        .opacity(state.isOnline ? 1 : 0.5)
    }

    // MARK: - Helpers

    private var gpuIndices: [Int] {
        state.latestSnapshot?.gpus.map(\.index).sorted() ?? []
    }

    private func historyForGPU(_ gpuIndex: Int) -> [(date: Date, metrics: GPUMetrics)] {
        state.history.compactMap { snapshot in
            guard let gpu = snapshot.gpus.first(where: { $0.index == gpuIndex }) else { return nil }
            return (snapshot.timestamp, gpu)
        }
    }

    private func processesForGPU(_ gpuIndex: Int, in snapshot: NodeSnapshot) -> [GPUProcess] {
        snapshot.processes.filter { $0.gpuIndex == gpuIndex }
    }
}

// MARK: - GPU Row

struct GPURow: View {
    let gpuIndex: Int
    let history: [(date: Date, metrics: GPUMetrics)]
    let processes: [GPUProcess]
    let timeWindow: TimeInterval

    @State private var showProcesses = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // Stats line
            if let latest = history.last?.metrics {
                HStack(spacing: Theme.Spacing.xs) {
                    Text("GPU \(gpuIndex)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    Text(latest.name)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Text("\(latest.utilizationPercent)%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.utilizationColor(latest.utilizationPercent))
                        .frame(width: 32, alignment: .trailing)

                    Text("\u{2022}")
                        .foregroundStyle(.quaternary)

                    Text("\(Int(latest.memoryPercent))%")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, alignment: .trailing)

                    Text("\u{2022}")
                        .foregroundStyle(.quaternary)

                    Text("\(latest.temperatureC)\u{00B0}C")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, alignment: .trailing)
                }
            }

            // Chart
            GPUMiniChart(history: history, timeWindow: timeWindow)

            // Process list (expandable)
            if !processes.isEmpty {
                DisclosureGroup(isExpanded: $showProcesses) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        ForEach(processes, id: \.pid) { proc in
                            HStack(spacing: 0) {
                                Text(proc.user)
                                    .frame(width: 56, alignment: .leading)
                                Text("\(proc.pid)")
                                    .frame(width: 56, alignment: .trailing)
                                Text("  \(proc.processName)")
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(proc.gpuMemoryMB) MB")
                                    .frame(width: 64, alignment: .trailing)
                            }
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                        }
                    }
                } label: {
                    Text("\(processes.count) process\(processes.count == 1 ? "" : "es")")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .contentShape(Rectangle())
                        .onTapGesture { showProcesses.toggle() }
                }
            }
        }
    }
}
