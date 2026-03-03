import SwiftUI

struct NodeEditorView: View {
    var viewModel: GPUViewModel
    var existingNode: GPUNode?

    @State private var displayName = ""
    @State private var hostname = ""
    @State private var port = ""
    @State private var authChoice = 0 // 0=sshConfig, 1=keyFile, 2=password
    @State private var keyFilePath = ""
    @State private var password = ""
    @State private var isTesting = false
    @State private var testResult: String?

    @Environment(\.dismiss) private var dismiss

    init(viewModel: GPUViewModel, existingNode: GPUNode? = nil) {
        self.viewModel = viewModel
        self.existingNode = existingNode

        if let node = existingNode {
            _displayName = State(initialValue: node.displayName)
            _hostname = State(initialValue: node.hostname)
            _port = State(initialValue: node.port.map(String.init) ?? "")
            switch node.authMethod {
            case .sshConfig:
                _authChoice = State(initialValue: 0)
            case .keyFile(let path):
                _authChoice = State(initialValue: 1)
                _keyFilePath = State(initialValue: path)
            case .password:
                _authChoice = State(initialValue: 2)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Display name", text: $displayName)
                    TextField("Hostname", text: $hostname, prompt: Text("user@host"))
                    TextField("Port", text: $port, prompt: Text("22"))
                }

                Section {
                    Picker("Authentication", selection: $authChoice) {
                        Text("System SSH Config").tag(0)
                        Text("Key File").tag(1)
                        Text("Password").tag(2)
                    }

                    if authChoice == 1 {
                        LabeledContent("Key file") {
                            HStack {
                                TextField("", text: $keyFilePath)
                                    .truncationMode(.middle)
                                Button("Browse...") {
                                    browseKeyFile()
                                }
                                .controlSize(.small)
                            }
                        }
                    }

                    if authChoice == 2 {
                        SecureField("Password", text: $password)
                    }
                }

                if let result = testResult {
                    Section {
                        let isSuccess = result.hasPrefix("OK")
                        Label {
                            Text(result)
                                .lineLimit(2)
                                .foregroundStyle(isSuccess ? .green : .red)
                        } icon: {
                            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(isSuccess ? .green : .red)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button(action: testConnection) {
                    HStack(spacing: Theme.Spacing.xs) {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Test Connection")
                    }
                }
                .disabled(hostname.isEmpty || isTesting)

                Spacer()

                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button(existingNode == nil ? "Add" : "Save") {
                    saveNode()
                    dismiss()
                }
                .disabled(displayName.isEmpty || hostname.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.lg)
        }
        .frame(width: 420)
    }

    // MARK: - Actions

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            do {
                let auth = buildSSHAuth()
                let output = try await viewModel.testConnection(
                    host: hostname,
                    port: port.isEmpty ? nil : Int(port),
                    auth: auth
                )
                testResult = "OK \u{2014} \(output.trimmingCharacters(in: .whitespacesAndNewlines))"
            } catch {
                testResult = "Failed: \(error.localizedDescription)"
            }
            isTesting = false
        }
    }

    private func saveNode() {
        let authMethod: AuthMethod
        switch authChoice {
        case 1: authMethod = .keyFile(keyFilePath)
        case 2: authMethod = .password
        default: authMethod = .sshConfig
        }

        if var existing = existingNode {
            existing.displayName = displayName
            existing.hostname = hostname
            existing.port = port.isEmpty ? nil : Int(port)
            existing.authMethod = authMethod
            viewModel.updateNode(existing)

            if authChoice == 2, !password.isEmpty {
                try? KeychainHelper.setPassword(password, for: existing.id)
            }
        } else {
            let node = GPUNode(
                hostname: hostname,
                displayName: displayName,
                port: port.isEmpty ? nil : Int(port),
                authMethod: authMethod
            )
            viewModel.addNode(node)

            if authChoice == 2, !password.isEmpty {
                try? KeychainHelper.setPassword(password, for: node.id)
            }
        }
    }

    private func buildSSHAuth() -> SSHAuth {
        switch authChoice {
        case 1: return .keyFile(keyFilePath)
        case 2: return .password(password)
        default: return .defaultConfig
        }
    }

    private func browseKeyFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".ssh")
        if panel.runModal() == .OK, let url = panel.url {
            keyFilePath = url.path
        }
    }
}
