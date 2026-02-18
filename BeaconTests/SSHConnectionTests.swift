import Foundation
import Testing
@testable import Beacon

/// Integration tests that connect to the Docker SSH test harness.
///
/// These tests require the harness to be running at localhost:2222.
/// They skip gracefully if the harness is not reachable.
@Suite("SSH Connection Integration", .tags(.integration))
struct SSHConnectionTests {
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
                // If we get any response or a connection-related error (not timeout/unreachable),
                // the port is open. SSH will reject HTTP, but that means the server is there.
                if error == nil {
                    continuation.resume(returning: true)
                    return
                }

                let nsError = error! as NSError
                // Connection reset/refused at the HTTP level means SSH is listening
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

    /// Auto-resolves any pending host key challenge with `.trustOnce`.
    ///
    /// Polls the service until a challenge appears, the connection completes,
    /// or the connection fails. If a challenge is found, it is resolved so that
    /// the handshake can proceed without blocking the test.
    @MainActor
    private func autoResolveHostKeyChallenge(for service: SSHConnectionService) async throws {
        for _ in 0..<50 {
            if service.pendingHostKeyChallenge != nil { break }
            if service.status == .connected || service.status.isFailed { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        if service.pendingHostKeyChallenge != nil {
            service.resolveHostKeyChallenge(.trustOnce)
        }
    }

    @Test @MainActor func connectWithCorrectPassword() async throws {
        try #require(await isHarnessAvailable(), "Docker harness not reachable — skipping")

        let service = SSHConnectionService()
        service.timeout = .seconds(10)

        service.connect(host: host, port: port, username: username, password: password)
        #expect(service.status == .connecting)

        // Resolve host key challenge so the handshake can proceed
        try await autoResolveHostKeyChallenge(for: service)

        // Wait for connection to complete
        for _ in 0..<50 {
            if service.status == .connected || service.status.isFailed { break }
            try await Task.sleep(for: .milliseconds(100))
        }

        #expect(service.status == .connected)
        await service.disconnect()
        #expect(service.status == .idle)
    }

    @Test @MainActor func connectWithWrongPassword() async throws {
        try #require(await isHarnessAvailable(), "Docker harness not reachable — skipping")

        let service = SSHConnectionService()
        service.timeout = .seconds(10)

        service.connect(host: host, port: port, username: username, password: "wrongpassword")

        // Resolve host key challenge so the handshake can proceed to auth
        try await autoResolveHostKeyChallenge(for: service)

        // Wait for auth failure
        for _ in 0..<50 {
            if service.status.isFailed { break }
            try await Task.sleep(for: .milliseconds(100))
        }

        if case .failed(let message) = service.status {
            #expect(message == "Authentication failed")
        } else {
            Issue.record("Expected .failed state, got \(service.status)")
        }
    }

    @Test @MainActor func disconnectTransitionsToIdle() async throws {
        try #require(await isHarnessAvailable(), "Docker harness not reachable — skipping")

        let service = SSHConnectionService()
        service.timeout = .seconds(10)

        service.connect(host: host, port: port, username: username, password: password)

        // Resolve host key challenge so the handshake can proceed
        try await autoResolveHostKeyChallenge(for: service)

        // Wait for connection
        for _ in 0..<50 {
            if service.status == .connected || service.status.isFailed { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(service.status == .connected)

        await service.disconnect()
        #expect(service.status == .idle)
    }

    @Test(.timeLimit(.minutes(1)))
    @MainActor func connectionToUnreachableHostTimesOut() async throws {
        let service = SSHConnectionService()
        service.timeout = .seconds(3) // Short timeout for test speed

        // Use a non-routable IP to trigger timeout
        service.connect(host: "192.0.2.1", port: 22, username: "test", password: "test")
        #expect(service.status == .connecting)

        // Wait for NIO connect timeout (3s) + our timeout task + buffer
        try await Task.sleep(for: .seconds(8))

        if case .failed(let message) = service.status {
            #expect(message == "Connection timed out")
        } else {
            Issue.record("Expected .failed with timeout, got \(service.status)")
        }
    }

    @Test @MainActor func connectionRefused() async throws {
        let service = SSHConnectionService()
        service.timeout = .seconds(10)

        // Port 19999 should not have anything listening
        service.connect(host: "localhost", port: 19999, username: "test", password: "test")

        // Wait for refusal
        try await Task.sleep(for: .seconds(5))

        if case .failed(let message) = service.status {
            #expect(message == "Connection refused")
        } else {
            Issue.record("Expected .failed with connection refused, got \(service.status)")
        }
    }
}

// MARK: - Test Tags

extension Tag {
    @Tag static var integration: Self
}
