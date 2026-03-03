import SwiftUI

struct GPUDetailPanel: View {
    var viewModel: GPUViewModel
    var onSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Node list
            ScrollView {
                VStack(spacing: 8) {
                    if viewModel.sortedNodeStates.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.sortedNodeStates, id: \.node.id) { state in
                            NodeSection(
                                state: state,
                                isActive: state.node.id == viewModel.activeNodeId,
                                chartTimeWindow: TimeInterval(viewModel.chartTimeWindowMinutes * 60),
                                onSelect: { viewModel.setActiveNode(state.node.id) },
                                onRefresh: { Task { await viewModel.refreshNode(state.node.id) } }
                            )
                        }
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .scrollIndicators(.never)
            .frame(maxHeight: Theme.Popover.maxScrollHeight)

            Divider()

            // Footer
            HStack {
                Button(action: onSettings) {
                    Label("Settings", systemImage: "gear")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { Task { await viewModel.refreshAll() } }) {
                    Label("Refresh All", systemImage: "arrow.clockwise")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .frame(width: Theme.Popover.width)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "desktopcomputer.trianglebadge.exclamationmark")
                .font(.system(size: 36))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            Text("No nodes configured")
                .font(.system(size: 15, weight: .semibold))
            Text("Add a GPU node in Settings")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Open Settings", action: onSettings)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
