// @preconcurrency: SSHClient is not Sendable but is internally thread-safe
// via NIO's EventLoop. All access is serialized through @MainActor isolation.
// TODO: Remove @preconcurrency when Citadel adds Sendable conformance.
@preconcurrency import Citadel
import Foundation
import NIOCore

/// Error thrown when the SSH connection exceeds the configured timeout.
struct ConnectionTimeoutError: Error {}

/// Wraps Citadel's `SSHClient` with observable connection state and timeout logic.
@MainActor @Observable
final class SSHConnectionService {
    // MARK: - Observable State

    /// The current connection state, observable from SwiftUI views.
    private(set) var status: ConnectionState = .idle

    // MARK: - Configuration

    /// Timeout duration for connection attempts.
    var timeout: Duration = .seconds(15)

    // MARK: - Private State

    private var client: SSHClient?
    private var connectTask: Task<Void, Never>?

    // MARK: - Connect

    /// Initiates an SSH connection with the given credentials.
    ///
    /// Races the SSH handshake against a configurable timeout. If the timeout
    /// fires first, the connection task is cancelled and status transitions
    /// to `.failed`.
    func connect(host: String, port: Int, username: String, password: String) {
        guard status == .idle || status.isFailed else { return }

        status = .connecting

        connectTask = Task {
            let timeoutTask = Task { [timeout] in
                try await Task.sleep(for: timeout)
                self.connectTask?.cancel()
            }

            do {
                // Set NIO's TCP connect timeout slightly longer than our app-level
                // timeout so our timeout always fires first with a deterministic message.
                let nioTimeoutSeconds = Int64(timeout.components.seconds) + 5
                let sshClient = try await SSHClient.connect(
                    host: host,
                    port: port,
                    authenticationMethod: .passwordBased(
                        username: username,
                        password: password
                    ),
                    hostKeyValidator: .acceptAnything(),
                    reconnect: .never,
                    connectTimeout: .seconds(nioTimeoutSeconds)
                )

                timeoutTask.cancel()

                if Task.isCancelled {
                    try? await sshClient.close()
                    if self.status == .connecting {
                        self.status = .failed(message: "Connection timed out")
                    }
                    return
                }

                self.client = sshClient
                self.status = .connected
            } catch is CancellationError {
                timeoutTask.cancel()
                if self.status == .connecting {
                    self.status = .failed(message: "Connection timed out")
                }
            } catch {
                timeoutTask.cancel()
                self.status = .failed(message: SSHErrorMapper.message(for: error))
            }
        }
    }

    // MARK: - Disconnect

    /// Gracefully disconnects the active SSH session.
    func disconnect() async {
        connectTask?.cancel()
        connectTask = nil

        if let client {
            try? await client.close()
            self.client = nil
        }

        status = .idle
    }

    // MARK: - Cancel

    /// Cancels an in-flight connection attempt without sending a disconnect.
    func cancel() {
        connectTask?.cancel()
        connectTask = nil
        status = .idle
    }
}
