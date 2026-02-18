import SwiftUI

/// Sheet for generating a new SSH key pair.
///
/// Presents two phases: an input form for the key label and algorithm,
/// followed by a success screen displaying the generated public key
/// ready for copying to a server.
struct KeyGenerationView: View {
    @Environment(SSHKeyStore.self) private var keyStore
    @Environment(\.dismiss) private var dismiss

    @State private var state: GenerationState = .input
    @State private var label = ""
    @State private var selectedKeyType: SSHKeyType = .ed25519
    @State private var errorMessage: String?
    @State private var showError = false

    /// The available key types that can be generated on-device.
    private var generatableKeyTypes: [SSHKeyType] {
        SSHKeyType.allCases.filter(\.supportsGeneration)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .input:
                    KeyGenerationInputForm(
                        label: $label,
                        selectedKeyType: $selectedKeyType,
                        generatableKeyTypes: generatableKeyTypes,
                        onGenerate: generateKey
                    )
                case .success(let publicKey):
                    KeyGenerationSuccessView(
                        publicKey: publicKey,
                        onDone: { dismiss() }
                    )
                }
            }
            .navigationTitle("Generate SSH Key")
            .toolbar {
                if case .input = state {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Generation Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    private func generateKey() {
        do {
            let keyPair = try SSHKeyGenerator.generate(type: selectedKeyType)
            let entry = SSHKeyEntry(
                label: label,
                keyType: selectedKeyType,
                publicKey: keyPair.publicKeyData,
                createdAt: .now
            )
            keyStore.save(privateKey: keyPair.privateKeyData, entry: entry)
            state = .success(publicKey: keyPair.publicKeyString)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Generation State

/// Tracks the current phase of the key generation flow.
private enum GenerationState {
    /// The user is entering a label and selecting an algorithm.
    case input
    /// Key generation succeeded; the public key is ready to display.
    case success(publicKey: String)
}

// MARK: - Input Form

/// The form where the user enters a key label and selects the algorithm.
private struct KeyGenerationInputForm: View {
    @Binding var label: String
    @Binding var selectedKeyType: SSHKeyType
    let generatableKeyTypes: [SSHKeyType]
    let onGenerate: () -> Void

    var body: some View {
        Form {
            Section {
                TextField("Label", text: $label)
                    .accessibilityLabel("Key label")
            } footer: {
                Text("A name to identify this key, such as \"Work laptop\".")
            }

            Section {
                Picker("Algorithm", selection: $selectedKeyType) {
                    ForEach(generatableKeyTypes) { keyType in
                        Text(keyType.displayName)
                            .tag(keyType)
                    }
                }
                .accessibilityLabel("Key algorithm")
            } footer: {
                Text("Ed25519 is recommended for most use cases.")
            }

            Section {
                Button("Generate", systemImage: "wand.and.stars.inverse", action: onGenerate)
                    .disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Generate SSH key")
            }
        }
    }
}

// MARK: - Success View

/// Displays the generated public key with copy and dismiss actions.
private struct KeyGenerationSuccessView: View {
    let publicKey: String
    let onDone: () -> Void

    @State private var showCopied = false

    var body: some View {
        List {
            Section {
                Text(publicKey)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            } header: {
                Text("Public Key")
            } footer: {
                Text("Add this key to your server's authorized_keys file.")
            }

            Section {
                Button("Copy to Clipboard", systemImage: "doc.on.doc", action: copyPublicKey)
                    .accessibilityLabel("Copy public key to clipboard")

                if showCopied {
                    Text("Copied!")
                        .foregroundStyle(.green)
                        .font(.footnote)
                        .transition(.opacity)
                }
            }

            Section {
                Button("Done", action: onDone)
                    .bold()
            }
        }
    }

    private func copyPublicKey() {
        UIPasteboard.general.string = publicKey
        showCopied = true

        Task {
            try? await Task.sleep(for: .seconds(2))
            showCopied = false
        }
    }
}
