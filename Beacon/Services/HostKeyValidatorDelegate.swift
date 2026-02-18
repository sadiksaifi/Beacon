@preconcurrency import NIOSSH
@preconcurrency import NIOCore

/// Bridges NIO's synchronous host key validation to async/await.
///
/// Created per-connection with a handler closure that runs on `@MainActor`.
/// Safety invariant: The only shared state is the immutable `handler` closure,
/// set once during init. Promise resolution is thread-safe by NIO's design.
// TODO: Remove @unchecked Sendable when NIOSSH adds Sendable conformance to delegate types.
final class HostKeyValidatorDelegate: NIOSSHClientServerAuthenticationDelegate, @unchecked Sendable {
    private let handler: @MainActor @Sendable (NIOSSHPublicKey) async -> TrustDecision

    init(handler: @escaping @MainActor @Sendable (NIOSSHPublicKey) async -> TrustDecision) {
        self.handler = handler
    }

    func validateHostKey(
        hostKey: NIOSSHPublicKey,
        validationCompletePromise: EventLoopPromise<Void>
    ) {
        let handler = self.handler
        Task { @MainActor in
            let decision = await handler(hostKey)
            switch decision {
            case .reject:
                validationCompletePromise.fail(HostKeyRejectedError())
            case .trustOnce, .trustAndSave:
                validationCompletePromise.succeed(())
            }
        }
    }
}
