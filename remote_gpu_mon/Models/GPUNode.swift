import Foundation

enum AuthMethod: Codable, Hashable {
    case sshConfig
    case keyFile(String)
    case password
}

struct GPUNode: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var hostname: String
    var displayName: String
    var port: Int?
    var authMethod: AuthMethod = .sshConfig
    var isEnabled: Bool = true
}
