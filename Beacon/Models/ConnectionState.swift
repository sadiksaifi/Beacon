import Foundation

/// Represents the current state of an SSH connection.
enum ConnectionState: Equatable {
    /// No connection attempt in progress.
    case idle

    /// SSH handshake is in progress.
    case connecting

    /// SSH session is active.
    case connected

    /// Connection attempt failed or connection was lost.
    case failed(message: String)

    /// Whether this state represents a failure.
    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}
