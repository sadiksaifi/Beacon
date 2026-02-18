import SwiftUI

/// Sheet presented when connecting to a host whose key is not yet trusted.
///
/// Displays the host's fingerprint and offers three options:
/// reject, trust once, or trust and save permanently.
struct UnknownHostPromptView: View {
    let challenge: HostKeyChallenge
    let onDecision: (TrustDecision) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section {
                        Text("You're connecting to \(challenge.hostname) for the first time. Verify the server's identity before continuing.")
                    }

                    Section("Server Fingerprint") {
                        LabeledContent("Host") {
                            Text("\(challenge.hostname):\(challenge.port)")
                        }
                        LabeledContent("Key Type") {
                            Text(challenge.keyType)
                        }
                        LabeledContent("Fingerprint") {
                            Text(challenge.fingerprint)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .accessibilityLabel("Server fingerprint: \(challenge.fingerprint)")
                        }
                    }
                }

                VStack {
                    Button("Trust and Save", systemImage: "lock.shield") {
                        onDecision(.trustAndSave)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Trust and save this host key permanently")

                    Button("Trust Once", systemImage: "lock.open") {
                        onDecision(.trustOnce)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Trust this host key for this session only")

                    Button("Don't Connect", role: .cancel) {
                        onDecision(.reject)
                    }
                    .accessibilityLabel("Reject host key and cancel connection")
                }
                .padding()
            }
            .navigationTitle("Unknown Host")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}
