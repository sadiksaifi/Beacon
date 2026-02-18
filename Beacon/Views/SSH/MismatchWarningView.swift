import SwiftUI

/// Sheet presented when a host's key has changed since the last trusted connection.
///
/// Displays a security warning with both the stored and new fingerprints,
/// and offers options to cancel or replace the stored key.
struct MismatchWarningView: View {
    let challenge: HostKeyChallenge
    let storedFingerprint: String
    let onDecision: (TrustDecision) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section {
                        Label {
                            Text("The host key for \(challenge.hostname) has changed. This could indicate a security threat or a server reconfiguration.")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                                .imageScale(.large)
                        }
                    }

                    Section("Previous Fingerprint") {
                        Text(storedFingerprint)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .accessibilityLabel("Previously trusted fingerprint: \(storedFingerprint)")
                    }

                    Section("New Fingerprint") {
                        LabeledContent("Host") {
                            Text("\(challenge.hostname):\(challenge.port)")
                        }
                        LabeledContent("Key Type") {
                            Text(challenge.keyType)
                        }
                        Text(challenge.fingerprint)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .accessibilityLabel("New server fingerprint: \(challenge.fingerprint)")
                    }
                }

                VStack {
                    Button("Cancel", role: .cancel) {
                        onDecision(.reject)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Reject changed host key and cancel connection")

                    Button("Replace and Connect", systemImage: "arrow.triangle.2.circlepath") {
                        onDecision(.trustAndSave)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Replace stored host key with new key and connect")
                }
                .padding()
            }
            .navigationTitle("Host Key Changed")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
    }
}
