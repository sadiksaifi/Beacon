import SwiftUI

/// Displays the public key in OpenSSH format with a copy-to-clipboard action.
struct PublicKeyDisplayView: View {
    let entry: SSHKeyEntry

    @State private var showCopied = false

    private var formattedPublicKey: String {
        SSHPublicKeyFormatter.format(
            publicKeyData: entry.publicKey,
            keyType: entry.keyType
        )
    }

    var body: some View {
        List {
            Section {
                PublicKeyText(text: formattedPublicKey)
            } header: {
                Text(entry.keyType.displayName)
            } footer: {
                Text("Created \(entry.createdAt, format: .dateTime.year().month().day())")
            }

            Section {
                CopyButton(
                    showCopied: showCopied,
                    onCopy: copyPublicKey
                )
            }
        }
        .navigationTitle(entry.label)
    }

    private func copyPublicKey() {
        UIPasteboard.general.string = formattedPublicKey
        showCopied = true

        Task {
            try? await Task.sleep(for: .seconds(2))
            showCopied = false
        }
    }
}

// MARK: - Public Key Text

/// Displays the public key string in a monospaced font with text selection enabled.
private struct PublicKeyText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
    }
}

// MARK: - Copy Button

/// A button that copies the public key and shows a brief confirmation.
private struct CopyButton: View {
    let showCopied: Bool
    let onCopy: () -> Void

    var body: some View {
        Button("Copy to Clipboard", systemImage: "doc.on.doc", action: onCopy)
            .accessibilityLabel("Copy public key to clipboard")

        if showCopied {
            Text("Copied!")
                .foregroundStyle(.green)
                .font(.footnote)
                .transition(.opacity)
        }
    }
}
