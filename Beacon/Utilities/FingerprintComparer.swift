/// Result of comparing a received fingerprint against a stored entry.
enum FingerprintComparison {
    /// The fingerprint matches the stored entry.
    case match

    /// The fingerprint differs from the stored entry.
    case mismatch

    /// No stored entry exists for this host.
    case unknown
}

/// Compares a host key fingerprint against a stored known host entry.
enum FingerprintComparer {
    /// Compares the given fingerprint against a stored entry.
    ///
    /// - Returns: `.unknown` if no stored entry, `.match` if fingerprints match,
    ///   `.mismatch` if they differ.
    static func compare(fingerprint: String, storedEntry: KnownHostEntry?) -> FingerprintComparison {
        guard let storedEntry else { return .unknown }
        return fingerprint == storedEntry.fingerprint ? .match : .mismatch
    }
}
