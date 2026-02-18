import Foundation
import Testing
@testable import Beacon

/// Integration tests that exercise `TerminalIOBridge` end-to-end against the
/// Docker SSH test harness running at localhost:2222.
///
/// Each test connects to the harness via `SSHConnectionService`, creates a
/// socketpair for the PTY file descriptor, and starts the bridge. Data written
/// to one end of the socketpair travels through the SSH shell channel and back.
///
/// These tests skip gracefully when the Docker harness is not reachable —
/// the `try #require(isHarnessAvailable)` guard exits the test immediately
/// with a clear message instead of blocking or crashing.
@Suite("Terminal I/O Bridge Integration", .tags(.integration))
struct TerminalIntegrationTests {
    private let host = "localhost"
    private let port = 2222
    private let username = "testuser"
    private let password = "testpass"

    // MARK: - Docker Availability

    /// TCP probe to check if the Docker harness is reachable.
    private func isHarnessAvailable() async -> Bool {
        await withCheckedContinuation { continuation in
            let task = URLSession.shared.dataTask(
                with: URL(string: "http://\(host):\(port)")!
            ) { _, _, error in
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

    // MARK: - Helpers

    /// Auto-resolves any pending host key challenge with `.trustOnce`.
    ///
    /// Polls the service until a challenge appears, the connection completes,
    /// or the connection fails.
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

    /// Connects via `SSHConnectionService`, waits for `.connected`, and returns
    /// the service. The caller is responsible for disconnecting.
    @MainActor
    private func connectToHarness() async throws -> SSHConnectionService {
        let service = SSHConnectionService()
        service.timeout = .seconds(10)

        service.connect(host: host, port: port, username: username, password: password)
        try await autoResolveHostKeyChallenge(for: service)

        for _ in 0..<50 {
            if service.status == .connected || service.status.isFailed { break }
            try await Task.sleep(for: .milliseconds(100))
        }

        try #require(service.status == .connected, "Expected .connected, got \(service.status)")
        return service
    }

    /// Creates a Unix socketpair and returns both file descriptors.
    /// The caller owns both FDs and is responsible for closing them.
    private func makeSocketpair() throws -> (masterFD: Int32, slaveFD: Int32) {
        var fds: [Int32] = [0, 0]
        let result = Darwin.socketpair(AF_UNIX, SOCK_STREAM, 0, &fds)
        guard result == 0 else {
            throw SocketpairError(errno: errno)
        }
        return (masterFD: fds[0], slaveFD: fds[1])
    }

    /// Waits until the bridge reaches the expected status or times out.
    @MainActor
    private func waitForBridgeStatus(
        _ bridge: TerminalIOBridge,
        matching predicate: (TerminalIOBridge.Status) -> Bool,
        timeout: Duration = .seconds(10)
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if predicate(bridge.status) { return }
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    // MARK: - Test Cases

    @Test("Connect and verify bridge starts")
    @MainActor func connectAndBridgeStarts() async throws {
        try #require(await isHarnessAvailable(), "Docker harness not reachable — skipping")

        let service = try await connectToHarness()
        defer { Task { await service.disconnect() } }

        let client = try #require(service.client, "SSHClient should not be nil after connecting")

        let (masterFD, slaveFD) = try makeSocketpair()
        defer { Darwin.close(masterFD) }
        // The bridge takes ownership of slaveFD and closes it on stop().

        let bridge = TerminalIOBridge()
        #expect(bridge.status == .idle)

        bridge.start(client: client, ptyFD: slaveFD)
        #expect(bridge.status == .running)

        // Give the relay tasks a moment to establish
        try await Task.sleep(for: .milliseconds(500))
        #expect(bridge.status == .running)

        bridge.stop()

        // After stop, status should be .disconnected (since it was .running)
        if case .disconnected = bridge.status {
            // Expected
        } else {
            Issue.record("Expected .disconnected after stop(), got \(bridge.status)")
        }
    }

    @Test("Send command and verify output round-trip")
    @MainActor func sendCommandAndVerifyOutput() async throws {
        try #require(await isHarnessAvailable(), "Docker harness not reachable — skipping")

        let service = try await connectToHarness()
        defer { Task { await service.disconnect() } }

        let client = try #require(service.client, "SSHClient should not be nil after connecting")

        let (masterFD, slaveFD) = try makeSocketpair()
        defer { Darwin.close(masterFD) }

        let bridge = TerminalIOBridge()
        bridge.start(client: client, ptyFD: slaveFD)
        #expect(bridge.status == .running)

        // Wait for the shell to be ready (prompt, MOTD, etc.)
        try await Task.sleep(for: .seconds(1))

        // Drain any initial output (MOTD, prompt) before sending our command
        drainFD(masterFD)

        // Write a command to the master end of the socketpair. This goes:
        // masterFD -> slaveFD -> bridge -> SSH channel -> server shell
        // and the output comes back:
        // server shell -> SSH channel -> bridge -> slaveFD -> masterFD
        let command = "echo hello\n"
        command.withCString { ptr in
            _ = Darwin.write(masterFD, ptr, command.utf8.count)
        }

        // Read output back from the master FD. The SSH server will echo the
        // command and then print the output. We accumulate reads until we see
        // "hello" in the output or we time out.
        var accumulated = ""
        let deadline = ContinuousClock.now + .seconds(5)

        while ContinuousClock.now < deadline {
            let chunk = readFromFD(masterFD, timeout: .milliseconds(200))
            accumulated += chunk

            if accumulated.contains("hello") {
                break
            }

            try await Task.sleep(for: .milliseconds(100))
        }

        #expect(accumulated.contains("hello"), "Expected 'hello' in output, got: \(accumulated)")

        bridge.stop()
    }

    @Test("Bridge detects disconnection when SSH client closes")
    @MainActor func disconnectDetected() async throws {
        try #require(await isHarnessAvailable(), "Docker harness not reachable — skipping")

        let service = try await connectToHarness()
        let client = try #require(service.client, "SSHClient should not be nil after connecting")

        let (masterFD, slaveFD) = try makeSocketpair()
        // masterFD is NOT deferred here — we close it manually to unblock the bridge.

        let bridge = TerminalIOBridge()
        bridge.start(client: client, ptyFD: slaveFD)
        #expect(bridge.status == .running)

        // Give bridge a moment to fully establish the shell channel
        try await Task.sleep(for: .seconds(1))

        // Disconnect the SSH client, simulating a lost connection.
        await service.disconnect()

        // The SSH -> Terminal relay will end when the channel closes, which
        // triggers `group.cancelAll()`. However, the Terminal -> SSH relay is
        // blocked on a `Darwin.read()` of the slave FD. Closing the master end
        // of the socketpair causes that read to return EOF, unblocking the task
        // group and allowing the bridge to update its status.
        Darwin.close(masterFD)

        // Wait for the bridge to notice the disconnection. It should transition
        // to either .disconnected or .error when the SSH channel closes.
        try await waitForBridgeStatus(
            bridge,
            matching: { status in
                switch status {
                case .disconnected, .error:
                    return true
                default:
                    return false
                }
            },
            timeout: .seconds(10)
        )

        switch bridge.status {
        case .disconnected:
            // Expected — the SSH channel closed cleanly
            break
        case .error:
            // Also acceptable — the channel may report an error on abrupt close
            break
        default:
            Issue.record("Expected .disconnected or .error, got \(bridge.status)")
        }
    }

    // MARK: - FD I/O Utilities

    /// Reads available bytes from a file descriptor with a short timeout.
    /// Returns the data as a UTF-8 string. Uses `select()` to avoid blocking.
    private func readFromFD(_ fd: Int32, timeout: Duration = .milliseconds(500)) -> String {
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        // Use select() to wait for data with a timeout
        var readSet = fd_set()
        withUnsafeMutablePointer(to: &readSet) { ptr in
            // Zero out the fd_set
            let rawPtr = UnsafeMutableRawPointer(ptr)
            rawPtr.initializeMemory(as: UInt8.self, repeating: 0, count: MemoryLayout<fd_set>.size)
        }

        // Set the bit for our FD
        let fdIndex = Int(fd)
        withUnsafeMutablePointer(to: &readSet) { ptr in
            let rawPtr = UnsafeMutableRawPointer(ptr)
            let wordSize = MemoryLayout<Int32>.size * 8  // bits per word
            let wordIndex = fdIndex / wordSize
            let bitIndex = fdIndex % wordSize
            let wordPtr = rawPtr.assumingMemoryBound(to: Int32.self).advanced(by: wordIndex)
            wordPtr.pointee |= Int32(1 << bitIndex)
        }

        let totalMilliseconds = Int(timeout.components.seconds) * 1000
            + Int(timeout.components.attoseconds / 1_000_000_000_000_000)
        var tv = timeval(
            tv_sec: Int(totalMilliseconds / 1000),
            tv_usec: Int32((totalMilliseconds % 1000) * 1000)
        )

        let selectResult = Darwin.select(fd + 1, &readSet, nil, nil, &tv)
        guard selectResult > 0 else {
            return ""
        }

        let bytesRead = Darwin.read(fd, buffer, bufferSize)
        guard bytesRead > 0 else {
            return ""
        }

        return String(bytes: UnsafeBufferPointer(start: buffer, count: bytesRead), encoding: .utf8) ?? ""
    }

    /// Drains all immediately available data from the file descriptor.
    private func drainFD(_ fd: Int32) {
        // Set non-blocking temporarily to drain
        let flags = fcntl(fd, F_GETFL)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while true {
            let bytesRead = Darwin.read(fd, buffer, bufferSize)
            if bytesRead <= 0 { break }
        }

        // Restore original flags
        _ = fcntl(fd, F_SETFL, flags)
    }
}

// MARK: - Errors

/// Error thrown when `socketpair()` fails.
private struct SocketpairError: Error, LocalizedError {
    let errno: Int32

    var errorDescription: String? {
        "socketpair() failed (errno \(errno): \(String(cString: strerror(errno))))"
    }
}
