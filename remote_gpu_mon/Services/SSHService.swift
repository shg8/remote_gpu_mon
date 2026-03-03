import Foundation

enum SSHAuth: Sendable {
    case defaultConfig
    case keyFile(String)
    case password(String)
}

enum SSHError: LocalizedError {
    case commandFailed(status: Int32, stderr: String)
    case processLaunchFailed(Error)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let status, let stderr):
            "SSH failed (exit \(status)): \(stderr.prefix(200))"
        case .processLaunchFailed(let error):
            "Failed to launch SSH: \(error.localizedDescription)"
        }
    }
}

final class SSHService {
    private var askpassPath: String?

    func execute(
        host: String,
        port: Int?,
        auth: SSHAuth,
        command: String,
        timeout: TimeInterval = 10
    ) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")

        var args: [String] = []
        args += ["-o", "ConnectTimeout=\(Int(timeout))"]
        args += ["-o", "StrictHostKeyChecking=accept-new"]

        var env: [String: String]? = nil

        switch auth {
        case .defaultConfig:
            args += ["-o", "BatchMode=yes"]
        case .keyFile(let path):
            args += ["-o", "BatchMode=yes"]
            args += ["-i", path]
        case .password(let pwd):
            let helper = try ensureAskpassHelper()
            env = ProcessInfo.processInfo.environment
            env?["SSH_ASKPASS"] = helper
            env?["SSH_ASKPASS_REQUIRE"] = "force"
            env?["DISPLAY"] = ":0"
            env?["GPU_MON_SSH_PASS"] = pwd
        }

        if let p = port {
            args += ["-p", "\(p)"]
        }

        args.append(host)
        args.append(command)

        process.arguments = args
        if let env { process.environment = env }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = FileHandle.nullDevice

        // Must read pipes BEFORE waitUntilExit to avoid deadlock when
        // output exceeds the pipe buffer (~64KB). Reading drains the buffer
        // so the process can continue writing and eventually exit.
        try process.run()

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                let output = String(data: outData, encoding: .utf8) ?? ""
                let errOutput = String(data: errData, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 || !output.isEmpty {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: SSHError.commandFailed(
                        status: process.terminationStatus,
                        stderr: errOutput
                    ))
                }
            }
        }
    }

    // MARK: - Askpass Helper

    private func ensureAskpassHelper() throws -> String {
        if let path = askpassPath, FileManager.default.fileExists(atPath: path) {
            return path
        }

        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let appDir = appSupport.appendingPathComponent("GPUMonitor")
        try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        let helperURL = appDir.appendingPathComponent("ssh-askpass.sh")
        let script = "#!/bin/sh\necho \"$GPU_MON_SSH_PASS\"\n"
        try script.write(to: helperURL, atomically: true, encoding: .utf8)

        var attrs = try FileManager.default.attributesOfItem(atPath: helperURL.path)
        attrs[.posixPermissions] = 0o700
        try FileManager.default.setAttributes(attrs, ofItemAtPath: helperURL.path)

        askpassPath = helperURL.path
        return helperURL.path
    }
}
