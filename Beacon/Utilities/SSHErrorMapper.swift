@preconcurrency import Citadel
import Foundation
import NIOCore
import NIOPosix

/// The authentication context used to tailor error messages.
enum SSHAuthContext {
    case password
    case key
}

/// Maps SSH and network errors to human-readable messages.
enum SSHErrorMapper {
    /// Returns a user-facing error message for the given error.
    ///
    /// - Parameters:
    ///   - error: The error to map.
    ///   - context: The authentication context, used to provide more specific
    ///     guidance for authentication failures.
    static func message(for error: Error, context: SSHAuthContext? = nil) -> String {
        // Custom timeout error
        if error is ConnectionTimeoutError {
            return "Connection timed out"
        }

        // Host key rejected by user or validator
        if error is HostKeyRejectedError {
            return "Host key rejected"
        }

        // Citadel authentication failures
        if error is AuthenticationFailed {
            return authFailureMessage(for: context)
        }

        if let clientError = error as? SSHClientError,
            clientError == .allAuthenticationOptionsFailed
        {
            return authFailureMessage(for: context)
        }

        // NIO connection errors — unwrap and inspect underlying failures
        if let nioError = error as? NIOConnectionError {
            return mapNIOConnectionError(nioError)
        }

        // NIO channel timeout
        if case ChannelError.connectTimeout = error {
            return "Connection timed out"
        }

        // POSIX errors
        if let message = mapPOSIXError(error) {
            return message
        }

        // URLError network conditions
        if let message = mapURLError(error) {
            return message
        }

        // String-based fallback matching
        let description = String(describing: error)

        if description.localizedStandardContains("authentication")
            || description.localizedStandardContains("auth fail")
        {
            return authFailureMessage(for: context)
        }

        // Generic fallback
        return "Connection failed: \(error.localizedDescription)"
    }

    // MARK: - Private Helpers

    private static func authFailureMessage(for context: SSHAuthContext?) -> String {
        switch context {
        case .key:
            "Key authentication failed — the server may not have your public key in authorized_keys."
        case .password, .none:
            "Authentication failed"
        }
    }

    private static func mapNIOConnectionError(_ error: NIOConnectionError) -> String {
        // Check each underlying connection error
        for failure in error.connectionErrors {
            let underlying = failure.error

            // NIO ChannelError.connectTimeout
            if case ChannelError.connectTimeout = underlying {
                return "Connection timed out"
            }

            // Check POSIX errors inside NIO wrapper
            if let posixMessage = mapPOSIXError(underlying) {
                return posixMessage
            }
        }

        // Fallback string-based check on the full error description
        let description = String(describing: error)

        if description.localizedStandardContains("connection refused") {
            return "Connection refused"
        }
        if description.localizedStandardContains("timed out")
            || description.localizedStandardContains("timeout")
        {
            return "Connection timed out"
        }

        return "Connection failed: \(error)"
    }

    private static func mapPOSIXError(_ error: Error) -> String? {
        let nsError = error as NSError
        if nsError.domain == NSPOSIXErrorDomain {
            switch nsError.code {
            case 61: return "Connection refused" // ECONNREFUSED
            case 51, 50: return "Network unavailable" // ENETUNREACH, ENETDOWN
            default: return nil
            }
        }

        // IOError wrapping POSIX errors (NIO uses this internally)
        if let ioError = error as? IOError {
            switch ioError.errnoCode {
            case 61: return "Connection refused" // ECONNREFUSED
            case 51, 50: return "Network unavailable" // ENETUNREACH, ENETDOWN
            default: return nil
            }
        }

        return nil
    }

    private static func mapURLError(_ error: Error) -> String? {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return nil }

        switch nsError.code {
        case NSURLErrorNotConnectedToInternet,
            NSURLErrorNetworkConnectionLost:
            return "Network unavailable"
        case NSURLErrorTimedOut:
            return "Connection timed out"
        default:
            return nil
        }
    }
}
