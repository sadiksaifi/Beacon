import SwiftUI
import UniformTypeIdentifiers

/// Sheet for importing an existing SSH private key from the clipboard or a file.
///
/// Uses a state machine to guide the user through parsing, optional passphrase
/// decryption, labelling, and finally saving the key to the store.
struct KeyImportView: View {
    @Environment(SSHKeyStore.self) private var keyStore
    @Environment(\.dismiss) private var dismiss

    @State private var importState: ImportState = .initial
    @State private var showFileImporter = false
    @State private var label = ""
    @State private var passphrase = ""

    var body: some View {
        NavigationStack {
            Group {
                switch importState {
                case .initial:
                    ImportSourceView(
                        onPaste: pasteFromClipboard,
                        onShowFileImporter: { showFileImporter = true }
                    )
                case .parsed(let privateKeyData, let keyType, let publicKeyData):
                    ParsedKeyForm(
                        keyType: keyType,
                        label: $label,
                        onImport: { saveKey(privateKeyData: privateKeyData, keyType: keyType, publicKeyData: publicKeyData) }
                    )
                case .encrypted(let keyType, let rawKeyString):
                    EncryptedKeyForm(
                        keyType: keyType,
                        passphrase: $passphrase,
                        onDecrypt: { decryptKey(keyType: keyType, rawKeyString: rawKeyString) }
                    )
                case .error(let message):
                    ImportErrorView(
                        message: message,
                        onRetry: { importState = .initial }
                    )
                }
            }
            .navigationTitle("Import SSH Key")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.data, .plainText, .item]
            ) { result in
                importFromFile(result: result)
            }
        }
    }

    // MARK: - Actions

    private func pasteFromClipboard() {
        guard let clipboardString = UIPasteboard.general.string else {
            importState = .error(message: "No text found on clipboard.")
            return
        }

        do {
            let result = try SSHKeyParser.parse(string: clipboardString)
            handleParseResult(result)
        } catch {
            importState = .error(message: error.localizedDescription)
        }
    }

    private func importFromFile(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                importState = .error(message: "Unable to access the selected file.")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let parseResult = try SSHKeyParser.parse(string: content)
                handleParseResult(parseResult)
            } catch {
                importState = .error(message: error.localizedDescription)
            }

        case .failure(let error):
            importState = .error(message: error.localizedDescription)
        }
    }

    private func handleParseResult(_ result: SSHKeyParser.ParseResult) {
        switch result {
        case .unencrypted(let privateKeyData, let keyType, let publicKeyData):
            importState = .parsed(privateKeyData: privateKeyData, keyType: keyType, publicKeyData: publicKeyData)
        case .encrypted(let keyType, let rawKeyString):
            importState = .encrypted(keyType: keyType, rawKeyString: rawKeyString)
        }
    }

    private func decryptKey(keyType: SSHKeyType, rawKeyString: String) {
        do {
            let result = try SSHKeyParser.decrypt(keyString: rawKeyString, passphrase: passphrase)
            handleParseResult(result)
        } catch {
            importState = .error(message: error.localizedDescription)
        }
    }

    private func saveKey(privateKeyData: Data, keyType: SSHKeyType, publicKeyData: Data) {
        let entry = SSHKeyEntry(
            label: label,
            keyType: keyType,
            publicKey: publicKeyData,
            createdAt: .now
        )
        keyStore.save(privateKey: privateKeyData, entry: entry)
        dismiss()
    }
}

// MARK: - Import State

/// Tracks the current phase of the key import flow.
private enum ImportState {
    /// Show import source buttons.
    case initial
    /// Parsed successfully; the user needs to provide a label.
    case parsed(privateKeyData: Data, keyType: SSHKeyType, publicKeyData: Data)
    /// The key is encrypted; the user needs to provide a passphrase.
    case encrypted(keyType: SSHKeyType, rawKeyString: String)
    /// An error occurred; show the message and a retry option.
    case error(message: String)
}

// MARK: - Import Source View

/// The initial screen presenting import source options.
private struct ImportSourceView: View {
    let onPaste: () -> Void
    let onShowFileImporter: () -> Void

    var body: some View {
        Form {
            Section {
                Button("Paste from Clipboard", systemImage: "doc.on.clipboard", action: onPaste)

                Button("Import from Files", systemImage: "folder", action: onShowFileImporter)
            } footer: {
                Text("Select the source of your SSH private key.")
            }
        }
    }
}

// MARK: - Parsed Key Form

/// Displayed after a key is successfully parsed, allowing the user to label and save it.
private struct ParsedKeyForm: View {
    let keyType: SSHKeyType
    @Binding var label: String
    let onImport: () -> Void

    private var trimmedLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            Section {
                Label(
                    "\(keyType.displayName) key detected",
                    systemImage: "checkmark.circle"
                )
                .foregroundStyle(.green)
            }

            Section {
                TextField("Label", text: $label)
            } footer: {
                Text("A name to identify this key, such as \"Work laptop\".")
            }

            Section {
                Button("Import", systemImage: "square.and.arrow.down", action: onImport)
                    .disabled(trimmedLabel.isEmpty)
            }
        }
    }
}

// MARK: - Encrypted Key Form

/// Displayed when the parsed key is encrypted, prompting for a passphrase.
private struct EncryptedKeyForm: View {
    let keyType: SSHKeyType
    @Binding var passphrase: String
    let onDecrypt: () -> Void

    var body: some View {
        Form {
            Section {
                Label(
                    "This key is encrypted",
                    systemImage: "lock.fill"
                )

                Text("\(keyType.displayName) key requires a passphrase to unlock.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                SecureField("Passphrase", text: $passphrase)
            }

            Section {
                Button("Decrypt", systemImage: "lock.open", action: onDecrypt)
                    .disabled(passphrase.isEmpty)
            }
        }
    }
}

// MARK: - Import Error View

/// Displayed when an import error occurs, showing the message and accepted formats.
private struct ImportErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        Form {
            Section {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }

            Section("Accepted Formats") {
                Text("OpenSSH format (ssh-ed25519, ssh-rsa)")
                Text("ECDSA P-256 PEM format")
            }

            Section {
                Button("Try Again", systemImage: "arrow.counterclockwise", action: onRetry)
            }
        }
    }
}

#Preview {
    KeyImportView()
        .environment(SSHKeyStore())
}
