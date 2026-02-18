// @preconcurrency: SSHClient is not Sendable but is internally thread-safe
// via NIO's EventLoop. TTYStdinWriter wraps a NIO Channel which is also not
// Sendable but is safe to use from any context via NIO's event loop.
// TODO: Remove @preconcurrency when Citadel adds Sendable conformance.
@preconcurrency import Citadel
import Foundation
import NIOCore
@preconcurrency import NIOSSH
import os

/// Bidirectional relay between a Citadel SSH shell channel and the
/// terminal emulator's PTY file descriptor.
///
/// The bridge runs two concurrent tasks inside a task group:
/// - **SSH to Terminal:** reads from the SSH channel's async output stream and
///   writes bytes to the PTY slave file descriptor.
/// - **Terminal to SSH:** reads user keystrokes from the PTY slave file
///   descriptor and writes them to the SSH channel via `TTYStdinWriter`.
///
/// Both tasks cancel automatically when the bridge is stopped, when an error
/// occurs, or when the SSH channel closes.
///
/// ## Data Flow
/// ```
/// SSH Server <-> Citadel Channel <-> TerminalIOBridge <-> slave FD (socketpair) <-> master FD (libghostty)
/// ```
@MainActor
@Observable
final class TerminalIOBridge {

    // MARK: - Types

    /// The current state of the I/O bridge.
    enum Status: Equatable {
        /// The bridge has not been started.
        case idle

        /// Both relay directions are actively running.
        case running

        /// The bridge was stopped or the SSH channel closed cleanly.
        case disconnected(reason: String)

        /// An unrecoverable error occurred during relay.
        case error(String)
    }

    // MARK: - Observable State

    /// The current bridge status, observable from SwiftUI views.
    private(set) var status: Status = .idle

    // MARK: - Private State

    /// The top-level task that owns the `withPTY` / bridge lifecycle.
    private var bridgeTask: Task<Void, Never>?

    /// The slave-side PTY file descriptor. Stored so it can be closed on teardown
    /// (the bridge owns this FD, not libghostty).
    private var slaveFD: Int32 = -1

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.beacon.app",
        category: "TerminalIOBridge"
    )

    /// Size of the read buffer used when reading from the PTY file descriptor.
    private nonisolated static let readBufferSize = 8192

    // MARK: - Public API

    /// Start the I/O bridge between an SSH client and the PTY file descriptor.
    ///
    /// Opens a PTY-backed shell channel on the given SSH client and begins
    /// relaying data in both directions. The bridge runs until `stop()` is
    /// called, an error occurs, or the SSH channel closes.
    ///
    /// - Parameters:
    ///   - client: An authenticated Citadel `SSHClient`.
    ///   - ptyFD: The slave-side file descriptor from `TerminalView.ptyFileDescriptor`.
    ///   - columns: Initial terminal width in columns.
    ///   - rows: Initial terminal height in rows.
    func start(
        client: SSHClient,
        ptyFD: Int32,
        columns: Int = 80,
        rows: Int = 24
    ) {
        guard status == .idle else {
            logger.warning("Cannot start bridge: status is \(String(describing: self.status))")
            return
        }

        guard ptyFD >= 0 else {
            status = .error("Invalid PTY file descriptor")
            return
        }

        slaveFD = ptyFD
        status = .running

        let bridgeLogger = logger
        bridgeTask = Task {
            let result = await Self.runBridge(
                client: client,
                ptyFD: ptyFD,
                columns: columns,
                rows: rows,
                logger: bridgeLogger
            )

            // Apply the result status back on MainActor.
            switch result {
            case .disconnected(let reason):
                if case .running = self.status {
                    self.status = .disconnected(reason: reason)
                }
            case .error(let message):
                self.status = .error(message)
            case .cancelled:
                if case .running = self.status {
                    self.status = .disconnected(reason: "Stopped by user")
                }
            }

            self.closeSlaveFD()
        }
    }

    /// Stop the bridge and clean up resources.
    ///
    /// Cancels both relay tasks, closes the slave FD, and transitions to
    /// `.disconnected`.
    func stop() {
        bridgeTask?.cancel()
        bridgeTask = nil
        closeSlaveFD()

        if case .running = status {
            status = .disconnected(reason: "Stopped by user")
        }
    }

    // MARK: - Bridge Lifecycle

    /// Result of the bridge relay, communicated back to the main actor.
    private enum BridgeResult: Sendable {
        case disconnected(reason: String)
        case error(String)
        case cancelled
    }

    /// Runs the bridge by opening a PTY shell channel on the SSH client and
    /// relaying I/O in both directions inside a task group.
    ///
    /// This is `nonisolated` so the `withPTY` closure does not need to cross
    /// a `@MainActor` isolation boundary, avoiding Sendable issues with
    /// `TTYOutput` and `TTYStdinWriter`.
    private nonisolated static func runBridge(
        client: SSHClient,
        ptyFD: Int32,
        columns: Int,
        rows: Int,
        logger: Logger
    ) async -> BridgeResult {
        do {
            let ptyRequest = SSHChannelRequestEvent.PseudoTerminalRequest(
                wantReply: true,
                term: "xterm-256color",
                terminalCharacterWidth: columns,
                terminalRowHeight: rows,
                terminalPixelWidth: 0,
                terminalPixelHeight: 0,
                terminalModes: .init([:])
            )

            try await client.withPTY(ptyRequest) { inbound, outbound in
                try await withThrowingTaskGroup(of: Void.self) { group in
                    // Direction 1: SSH -> Terminal
                    // Read from the SSH channel's async output stream
                    // and write to the PTY FD.
                    group.addTask {
                        try await relaySshToTerminal(
                            inbound: inbound,
                            ptyFD: ptyFD,
                            logger: logger
                        )
                    }

                    // Direction 2: Terminal -> SSH
                    // Read keystrokes from the PTY FD and write to the
                    // SSH channel.
                    group.addTask {
                        try await relayTerminalToSsh(
                            outbound: outbound,
                            ptyFD: ptyFD,
                            logger: logger
                        )
                    }

                    // Wait for the first task to finish (either direction
                    // failing or the channel closing means the bridge is
                    // done). Cancel the remaining task so both directions
                    // tear down together.
                    try await group.next()
                    group.cancelAll()
                }
            }

            // The withPTY closure returned normally — channel closed cleanly.
            if Task.isCancelled {
                return .cancelled
            }
            return .disconnected(reason: "Connection closed")
        } catch is CancellationError {
            return .cancelled
        } catch {
            logger.error("Bridge error: \(error.localizedDescription)")
            return .error(error.localizedDescription)
        }
    }

    // MARK: - Relay: SSH -> Terminal

    /// Reads data from the SSH channel and writes it to the PTY slave FD.
    ///
    /// Runs as a nonisolated static method so it can execute in a child task
    /// without crossing `@MainActor` isolation boundaries.
    private nonisolated static func relaySshToTerminal(
        inbound: TTYOutput,
        ptyFD: Int32,
        logger: Logger
    ) async throws {
        for try await output in inbound {
            try Task.checkCancellation()

            let buffer: ByteBuffer
            switch output {
            case .stdout(let data):
                buffer = data
            case .stderr(let data):
                // Stderr from a PTY session is unusual but we relay it too.
                buffer = data
            }

            let bytes = buffer.readableBytesView
            guard !bytes.isEmpty else { continue }

            // Write all bytes to the PTY FD. Darwin.write() may write fewer
            // bytes than requested, so loop until everything is written.
            try bytes.withUnsafeBytes { rawBuffer in
                var totalWritten = 0
                while totalWritten < rawBuffer.count {
                    let written = Darwin.write(
                        ptyFD,
                        rawBuffer.baseAddress! + totalWritten,
                        rawBuffer.count - totalWritten
                    )
                    if written < 0 {
                        let code = errno
                        if code == EAGAIN || code == EINTR {
                            continue
                        }
                        throw BridgeIOError.writeFailed(errno: code)
                    }
                    totalWritten += written
                }
            }
        }

        logger.info("SSH channel stream ended")
    }

    // MARK: - Relay: Terminal -> SSH

    /// Reads user input from the PTY slave FD and writes it to the SSH channel.
    ///
    /// The `Darwin.read()` call is blocking, so this runs inside a task group
    /// child task. When the task is cancelled, the FD will be closed by `stop()`
    /// which causes `read()` to return with an error, breaking the loop.
    private nonisolated static func relayTerminalToSsh(
        outbound: TTYStdinWriter,
        ptyFD: Int32,
        logger: Logger
    ) async throws {
        let bufferSize = readBufferSize
        let rawBuffer = UnsafeMutableRawPointer.allocate(
            byteCount: bufferSize,
            alignment: 1
        )
        defer { rawBuffer.deallocate() }

        while !Task.isCancelled {
            let bytesRead = Darwin.read(ptyFD, rawBuffer, bufferSize)

            if bytesRead > 0 {
                // Construct a ByteBuffer from the raw bytes and send to SSH.
                let byteBuffer = ByteBuffer(
                    bytes: UnsafeRawBufferPointer(start: rawBuffer, count: bytesRead)
                )
                try await outbound.write(byteBuffer)
            } else if bytesRead == 0 {
                // EOF — the other end of the socketpair closed.
                logger.info("PTY FD returned EOF")
                break
            } else {
                // bytesRead < 0: error
                let code = errno
                if code == EAGAIN || code == EINTR {
                    continue
                }
                if code == EBADF || code == EINVAL {
                    // FD was closed (e.g. by stop()), treat as clean shutdown.
                    logger.info("PTY FD closed (errno=\(code))")
                    break
                }
                throw BridgeIOError.readFailed(errno: code)
            }
        }
    }

    // MARK: - Cleanup

    /// Closes the slave FD if it is still open.
    private func closeSlaveFD() {
        if slaveFD >= 0 {
            Darwin.close(slaveFD)
            slaveFD = -1
        }
    }
}

// MARK: - Bridge I/O Errors

/// Errors that can occur during PTY file descriptor I/O.
enum BridgeIOError: Error, LocalizedError {
    case readFailed(errno: Int32)
    case writeFailed(errno: Int32)

    var errorDescription: String? {
        switch self {
        case .readFailed(let code):
            "Failed to read from PTY (errno \(code): \(String(cString: strerror(code))))"
        case .writeFailed(let code):
            "Failed to write to PTY (errno \(code): \(String(cString: strerror(code))))"
        }
    }
}
