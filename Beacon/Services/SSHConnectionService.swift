// @preconcurrency: SSHClient is not Sendable but is internally thread-safe
// via NIO's EventLoop. All access is serialized through @MainActor isolation.
// TODO: Remove @preconcurrency when Citadel adds Sendable conformance.
@preconcurrency import Citadel
import CryptoKit
import Foundation
@preconcurrency import NIOSSH
import NIOCore

/// Error thrown when the SSH connection exceeds the configured timeout.
struct ConnectionTimeoutError: Error {}

/// Error thrown when a host key is rejected by the validator.
struct HostKeyRejectedError: Error {}

/// Data bundle for a pending host key challenge awaiting user input.
struct PendingHostKeyChallenge: Identifiable {
    var id: UUID { challenge.id }
    let challenge: HostKeyChallenge
    let comparison: FingerprintComparison
    let storedFingerprint: String?
    let algorithm: String
}

/// Wraps Citadel's `SSHClient` with observable connection state and timeout logic.
@MainActor @Observable
final class SSHConnectionService {
    // MARK: - Observable State

    /// The current connection state, observable from SwiftUI views.
    private(set) var status: ConnectionState = .idle

    /// Set when the user needs to approve an unknown or changed host key.
    private(set) var pendingHostKeyChallenge: PendingHostKeyChallenge?

    // MARK: - Configuration

    /// Timeout duration for connection attempts.
    var timeout: Duration = .seconds(15)

    // MARK: - Dependencies

    /// In-memory and Keychain store for trusted host keys.
    let knownHostsStore = KnownHostsStore()

    // MARK: - Private State

    private var client: SSHClient?
    private var connectTask: Task<Void, Never>?
    private var pendingContinuation: CheckedContinuation<TrustDecision, Never>?

    // MARK: - Connect

    /// Initiates an SSH connection with the given credentials.
    ///
    /// Races the SSH handshake against a configurable timeout. If the timeout
    /// fires first, the connection task is cancelled and status transitions
    /// to `.failed`.
    func connect(host: String, port: Int, username: String, password: String) {
        guard status == .idle || status.isFailed else { return }

        status = .connecting

        let delegate = HostKeyValidatorDelegate { hostKey in
            await self.handleHostKey(hostKey, host: host, port: port)
        }

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
                    hostKeyValidator: .custom(delegate),
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
            } catch is HostKeyRejectedError {
                timeoutTask.cancel()
                if self.status == .connecting {
                    self.status = .failed(message: "Host key rejected")
                }
            } catch {
                timeoutTask.cancel()
                self.status = .failed(message: SSHErrorMapper.message(for: error))
            }
        }
    }

    // MARK: - Host Key Verification

    /// Handles host key validation during SSH handshake.
    ///
    /// Computes the key fingerprint, checks the known hosts store, and either
    /// auto-accepts (match) or suspends for user input (unknown/mismatch).
    func handleHostKey(_ hostKey: NIOSSHPublicKey, host: String, port: Int) async -> TrustDecision {
        let (fingerprint, keyType, algorithm) = computeFingerprint(from: hostKey)

        let storedEntry = knownHostsStore.lookup(host: host, port: port)
        let comparison = FingerprintComparer.compare(
            fingerprint: fingerprint,
            storedEntry: storedEntry
        )

        switch comparison {
        case .match:
            return .trustAndSave
        case .unknown, .mismatch:
            let challenge = HostKeyChallenge(
                hostname: host,
                port: port,
                keyType: keyType,
                fingerprint: fingerprint
            )

            pendingHostKeyChallenge = PendingHostKeyChallenge(
                challenge: challenge,
                comparison: comparison,
                storedFingerprint: storedEntry?.fingerprint,
                algorithm: algorithm
            )

            return await withCheckedContinuation { continuation in
                pendingContinuation = continuation
            }
        }
    }

    /// Resolves the pending host key challenge with the user's decision.
    func resolveHostKeyChallenge(_ decision: TrustDecision) {
        guard let challenge = pendingHostKeyChallenge else { return }

        switch decision {
        case .trustAndSave:
            let entry = KnownHostEntry(
                hostname: challenge.challenge.hostname,
                port: challenge.challenge.port,
                algorithm: challenge.algorithm,
                fingerprint: challenge.challenge.fingerprint,
                trustedAt: .now
            )
            knownHostsStore.save(entry)
        case .trustOnce:
            let entry = KnownHostEntry(
                hostname: challenge.challenge.hostname,
                port: challenge.challenge.port,
                algorithm: challenge.algorithm,
                fingerprint: challenge.challenge.fingerprint,
                trustedAt: .now
            )
            knownHostsStore.trustOnce(entry)
        case .reject:
            break
        }

        pendingHostKeyChallenge = nil
        pendingContinuation?.resume(returning: decision)
        pendingContinuation = nil
    }

    // MARK: - Disconnect

    /// Gracefully disconnects the active SSH session.
    func disconnect() async {
        rejectPendingChallenge()
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
        rejectPendingChallenge()
        connectTask?.cancel()
        connectTask = nil
        status = .idle
    }

    // MARK: - Private

    /// Rejects any pending host key challenge to prevent continuation leaks.
    private func rejectPendingChallenge() {
        pendingHostKeyChallenge = nil
        pendingContinuation?.resume(returning: .reject)
        pendingContinuation = nil
    }

    /// Computes the SHA-256 fingerprint and key type from an SSH public key.
    private func computeFingerprint(
        from hostKey: NIOSSHPublicKey
    ) -> (fingerprint: String, keyType: String, algorithm: String) {
        var buffer = ByteBufferAllocator().buffer(capacity: 256)
        _ = hostKey.write(to: &buffer)

        let keyData = Data(buffer.readableBytesView)
        let hash = SHA256.hash(data: keyData)
        let base64 = Data(hash).base64EncodedString()
        let fingerprint = "SHA256:\(base64)"

        let algorithm = parseKeyType(from: keyData)
        let keyType = displayName(for: algorithm)

        return (fingerprint, keyType, algorithm)
    }

    /// Parses the key type string from SSH wire format bytes.
    ///
    /// SSH wire format: first 4 bytes are a big-endian UInt32 string length,
    /// followed by the key type string (e.g. "ssh-ed25519").
    private func parseKeyType(from data: Data) -> String {
        guard data.count >= 4 else { return "unknown" }

        let length = Int(
            UInt32(data[0]) << 24 | UInt32(data[1]) << 16
                | UInt32(data[2]) << 8 | UInt32(data[3])
        )
        let endIndex = min(4 + length, data.count)
        let typeData = data[4..<endIndex]

        return String(data: typeData, encoding: .utf8) ?? "unknown"
    }

    /// Maps SSH key algorithm identifiers to human-readable display names.
    private func displayName(for algorithm: String) -> String {
        switch algorithm {
        case "ssh-ed25519": "Ed25519"
        case "ecdsa-sha2-nistp256", "ecdsa-sha2-nistp384", "ecdsa-sha2-nistp521": "ECDSA"
        case "ssh-rsa": "RSA"
        default: algorithm
        }
    }
}
