import Foundation
import Testing
@testable import Beacon

// MARK: - Unit Tests

@Suite("Fingerprint Comparison")
struct FingerprintComparisonTests {
    @Test func nilStoredEntryReturnsUnknown() {
        let result = FingerprintComparer.compare(
            fingerprint: "SHA256:abc123",
            storedEntry: nil
        )
        #expect(result == .unknown)
    }

    @Test func matchingFingerprintReturnsMatch() {
        let entry = KnownHostEntry(
            hostname: "example.com",
            port: 22,
            algorithm: "ssh-ed25519",
            fingerprint: "SHA256:abc123",
            trustedAt: .now
        )

        let result = FingerprintComparer.compare(
            fingerprint: "SHA256:abc123",
            storedEntry: entry
        )
        #expect(result == .match)
    }

    @Test func differentFingerprintReturnsMismatch() {
        let entry = KnownHostEntry(
            hostname: "example.com",
            port: 22,
            algorithm: "ssh-ed25519",
            fingerprint: "SHA256:abc123",
            trustedAt: .now
        )

        let result = FingerprintComparer.compare(
            fingerprint: "SHA256:xyz789",
            storedEntry: entry
        )
        #expect(result == .mismatch)
    }
}

@Suite("Known Hosts Store — Session Trust")
struct KnownHostsSessionTrustTests {
    @Test @MainActor func trustOnceStoresEntryInSession() {
        let store = KnownHostsStore()

        let entry = KnownHostEntry(
            hostname: "example.com",
            port: 22,
            algorithm: "ssh-ed25519",
            fingerprint: "SHA256:abc123",
            trustedAt: .now
        )
        store.trustOnce(entry)

        let result = store.lookup(host: "example.com", port: 22)
        #expect(result != nil)
        #expect(result?.fingerprint == "SHA256:abc123")
        #expect(result?.algorithm == "ssh-ed25519")
        #expect(result?.hostname == "example.com")
        #expect(result?.port == 22)
    }

    @Test @MainActor func differentPortsAreIndependent() {
        let store = KnownHostsStore()

        let entry22 = KnownHostEntry(
            hostname: "example.com",
            port: 22,
            algorithm: "ssh-ed25519",
            fingerprint: "SHA256:port22",
            trustedAt: .now
        )
        let entry2222 = KnownHostEntry(
            hostname: "example.com",
            port: 2222,
            algorithm: "ssh-ed25519",
            fingerprint: "SHA256:port2222",
            trustedAt: .now
        )

        store.trustOnce(entry22)
        store.trustOnce(entry2222)

        let result22 = store.lookup(host: "example.com", port: 22)
        let result2222 = store.lookup(host: "example.com", port: 2222)

        #expect(result22?.fingerprint == "SHA256:port22")
        #expect(result2222?.fingerprint == "SHA256:port2222")
    }

    @Test @MainActor func newStoreInstanceDoesNotHaveSessionEntries() {
        let store1 = KnownHostsStore()

        let entry = KnownHostEntry(
            hostname: "session-only.test",
            port: 22,
            algorithm: "ssh-ed25519",
            fingerprint: "SHA256:sessiononly",
            trustedAt: .now
        )
        store1.trustOnce(entry)

        let store2 = KnownHostsStore()
        let result = store2.lookup(host: "session-only.test", port: 22)
        #expect(result == nil)
    }
}

// MARK: - Integration Tests

@Suite("Host Key Verification Integration", .tags(.integration))
struct HostKeyVerificationIntegrationTests {
    private let host = "localhost"
    private let port = 2222
    private let username = "testuser"
    private let password = "testpass"

    /// TCP probe to check if the Docker harness is reachable.
    private func isHarnessAvailable() async -> Bool {
        await withCheckedContinuation { continuation in
            let task = URLSession.shared.dataTask(
                with: URL(string: "http://\(host):\(port)")!
            ) { _, response, error in
                if error == nil {
                    continuation.resume(returning: true)
                    return
                }

                let nsError = error! as NSError
                if nsError.domain == NSURLErrorDomain
                    && nsError.code != NSURLErrorCannotConnectToHost
                    && nsError.code != NSURLErrorTimedOut
                    && nsError.code != NSURLErrorNotConnectedToInternet
                {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(returning: false)
                }
            }
            task.resume()
        }
    }

    /// Waits for a pending host key challenge to appear on the service.
    @MainActor
    private func waitForChallenge(
        on service: SSHConnectionService
    ) async throws -> PendingHostKeyChallenge {
        for _ in 0..<50 {
            if let challenge = service.pendingHostKeyChallenge {
                return challenge
            }
            if service.status == .connected || service.status.isFailed {
                break
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw WaitError(message: "Host key challenge did not appear (status: \(service.status))")
    }

    /// Waits for the service to reach a terminal state (connected or failed).
    @MainActor
    private func waitForTerminalState(
        on service: SSHConnectionService
    ) async throws {
        for _ in 0..<50 {
            if service.status == .connected || service.status.isFailed {
                return
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw WaitError(message: "Service did not reach terminal state (status: \(service.status))")
    }

    @Test @MainActor func unknownHostPresentsChallenge() async throws {
        try #require(await isHarnessAvailable(), "Docker harness not reachable — skipping")

        let service = SSHConnectionService()
        service.timeout = .seconds(10)

        // Clean any stored entry from prior test runs
        service.knownHostsStore.delete(host: host, port: port)

        service.connect(host: host, port: port, username: username, password: password)

        let challenge = try await waitForChallenge(on: service)
        #expect(challenge.comparison == .unknown)
        #expect(challenge.storedFingerprint == nil)
        #expect(challenge.challenge.hostname == host)
        #expect(challenge.challenge.port == port)
        #expect(challenge.challenge.fingerprint.hasPrefix("SHA256:"))

        // Clean up: reject and wait for failure
        service.resolveHostKeyChallenge(.reject)
        try await waitForTerminalState(on: service)

        // Also clean up Keychain
        service.knownHostsStore.delete(host: host, port: port)
    }

    @Test @MainActor func rejectCausesFailure() async throws {
        try #require(await isHarnessAvailable(), "Docker harness not reachable — skipping")

        let service = SSHConnectionService()
        service.timeout = .seconds(10)

        // Clean any stored entry from prior test runs
        service.knownHostsStore.delete(host: host, port: port)

        service.connect(host: host, port: port, username: username, password: password)

        _ = try await waitForChallenge(on: service)

        service.resolveHostKeyChallenge(.reject)
        try await waitForTerminalState(on: service)

        if case .failed(let message) = service.status {
            #expect(message == "Host key rejected")
        } else {
            Issue.record("Expected .failed(\"Host key rejected\"), got \(service.status)")
        }
    }

    @Test @MainActor func trustAndSaveAllowsSilentReconnection() async throws {
        try #require(await isHarnessAvailable(), "Docker harness not reachable — skipping")

        // First connection: trust and save to Keychain
        let service1 = SSHConnectionService()
        service1.timeout = .seconds(10)
        service1.knownHostsStore.delete(host: host, port: port)

        service1.connect(host: host, port: port, username: username, password: password)

        _ = try await waitForChallenge(on: service1)
        service1.resolveHostKeyChallenge(.trustAndSave)

        try await waitForTerminalState(on: service1)
        #expect(service1.status == .connected)

        await service1.disconnect()

        // Second connection: new service instance should find fingerprint in Keychain
        let service2 = SSHConnectionService()
        service2.timeout = .seconds(10)

        service2.connect(host: host, port: port, username: username, password: password)

        // Should go straight to connected with no challenge
        try await waitForTerminalState(on: service2)

        #expect(service2.pendingHostKeyChallenge == nil)
        #expect(service2.status == .connected)

        await service2.disconnect()

        // Clean up Keychain
        service2.knownHostsStore.delete(host: host, port: port)
    }

    @Test @MainActor func trustOncePromptsAgainOnNewInstance() async throws {
        try #require(await isHarnessAvailable(), "Docker harness not reachable — skipping")

        // First connection: trust once (session-only)
        let service1 = SSHConnectionService()
        service1.timeout = .seconds(10)
        service1.knownHostsStore.delete(host: host, port: port)

        service1.connect(host: host, port: port, username: username, password: password)

        _ = try await waitForChallenge(on: service1)
        service1.resolveHostKeyChallenge(.trustOnce)

        try await waitForTerminalState(on: service1)
        #expect(service1.status == .connected)

        await service1.disconnect()

        // Second connection: new service instance should NOT find the entry
        // (session trust doesn't persist across instances)
        let service2 = SSHConnectionService()
        service2.timeout = .seconds(10)

        service2.connect(host: host, port: port, username: username, password: password)

        // Should present a challenge again
        let challenge = try await waitForChallenge(on: service2)
        #expect(challenge.comparison == .unknown)

        // Clean up: reject and wait
        service2.resolveHostKeyChallenge(.reject)
        try await waitForTerminalState(on: service2)

        // Clean up Keychain just in case
        service2.knownHostsStore.delete(host: host, port: port)
    }
}

// MARK: - Helpers

/// Error thrown when a wait condition is not met within the polling window.
private struct WaitError: Error {
    let message: String
}
