/// The user's decision when presented with a host key challenge.
enum TrustDecision {
    /// Reject the host key and abort the connection.
    case reject

    /// Trust the host key for this session only (not persisted).
    case trustOnce

    /// Trust the host key and save it to Keychain for future connections.
    case trustAndSave
}
