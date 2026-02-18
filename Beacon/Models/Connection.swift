import Foundation
import SwiftData

/// A persisted SSH connection configuration.
@Model
final class Connection {
    /// Stable identifier used for Keychain keying. Survives SwiftData migrations.
    var id: UUID = UUID()

    /// Display name for the connection. Optional; falls back to host if empty.
    var label: String = ""

    /// Hostname or IP address of the remote server.
    var host: String = ""

    /// SSH port number (1–65535).
    var port: Int = 22

    /// Username for authentication.
    var username: String = ""

    /// The authentication method to use.
    var authMethod: AuthMethod = AuthMethod.password

    /// The UUID of the selected SSH key when using key-based authentication.
    var selectedKeyID: UUID? = nil

    init(label: String = "", host: String, port: Int = 22, username: String, authMethod: AuthMethod = .password) {
        self.label = label
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
    }
}
