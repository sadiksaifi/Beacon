import Foundation

/// The authentication method used for an SSH connection.
enum AuthMethod: String, Codable, CaseIterable {
    case password
    case key
}
