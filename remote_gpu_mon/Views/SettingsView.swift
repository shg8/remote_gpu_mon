import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: GPUViewModel
    @State private var showingAddNode = false
    @State private var editingNode: GPUNode?

    var body: some View {
        Form {
            Section("Nodes") {
                if viewModel.sortedNodeStates.isEmpty {
                    Text("No nodes configured")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.sortedNodeStates, id: \.node.id) { state in
                        HStack(spacing: Theme.Spacing.sm) {
                            Circle()
                                .fill(state.isOnline ? .green : .gray)
                                .frame(width: 8, height: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(state.node.displayName)
                                Text(state.node.hostname)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                editingNode = state.node
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)

                            Button(role: .destructive) {
                                viewModel.removeNode(state.node.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                Button("Add Node...") {
                    showingAddNode = true
                }
            }

            Section("General") {
                LabeledContent("Polling interval") {
                    HStack(spacing: Theme.Spacing.xs) {
                        TextField("", value: $viewModel.pollingInterval, format: .number)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                        Text("seconds")
                            .foregroundStyle(.secondary)
                    }
                }

                Picker("Chart time window", selection: $viewModel.chartTimeWindowMinutes) {
                    Text("5 minutes").tag(5)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                    Text("6 hours").tag(360)
                }

                Picker("Data retention", selection: $viewModel.dataRetentionHours) {
                    Text("1 hour").tag(1)
                    Text("6 hours").tag(6)
                    Text("24 hours").tag(24)
                    Text("3 days").tag(72)
                    Text("7 days").tag(168)
                }

                Toggle("Launch at login", isOn: $viewModel.launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .frame(width: Theme.Settings.width)
        .frame(minHeight: Theme.Settings.minHeight, idealHeight: Theme.Settings.idealHeight)
        .sheet(isPresented: $showingAddNode) {
            NodeEditorView(viewModel: viewModel)
        }
        .sheet(item: $editingNode) { node in
            NodeEditorView(viewModel: viewModel, existingNode: node)
        }
    }
}
