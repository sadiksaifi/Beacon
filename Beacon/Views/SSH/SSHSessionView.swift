import Accessibility
import SwiftUI

/// Manages the SSH session lifecycle for a given connection.
///
/// On appearance, checks Keychain for a stored password. If found, connects
/// directly. If not, presents a password prompt sheet.
/// Phase 6 will replace the connected-state placeholder with a terminal surface.
struct SSHSessionView: View {
    @Environment(SSHConnectionService.self) private var connectionService
    @Environment(\.dismiss) private var dismiss

    let connection: Connection

    @State private var showPasswordPrompt = false
    @State private var showSavePasswordAlert = false
    @State private var pendingPassword: String?
    @State private var usedKeychainPassword = false

    var body: some View {
        Group {
            switch connectionService.status {
            case .idle:
                ContentUnavailableView {
                    ProgressView()
                } description: {
                    Text("Preparing…")
                }

            case .connecting:
                ConnectingStateView()

            case .connected:
                ConnectedStateView {
                    Task {
                        await connectionService.disconnect()
                        dismiss()
                    }
                }

            case .failed(let message):
                FailedStateView(message: message) {
                    retryConnection()
                }
            }
        }
        .navigationTitle(connection.label.isEmpty ? connection.host : connection.label)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(connectionService.status == .connecting)
        .toolbar {
            if connectionService.status == .connecting {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        connectionService.cancel()
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showPasswordPrompt, onDismiss: handlePasswordPromptDismiss) {
            PasswordPromptView { password in
                pendingPassword = password
                showPasswordPrompt = false
                connectWith(password: password)
            } onCancel: {
                showPasswordPrompt = false
            }
        }
        .alert("Save Password?", isPresented: $showSavePasswordAlert) {
            Button("Save") {
                if let password = pendingPassword {
                    KeychainService.store(password: password, forConnectionID: connection.id)
                }
                pendingPassword = nil
            }
            Button("Not Now", role: .cancel) {
                pendingPassword = nil
            }
        } message: {
            Text("Save password for future connections?")
        }
        .sheet(
            item: Binding<PendingHostKeyChallenge?>(
                get: {
                    guard let pending = connectionService.pendingHostKeyChallenge,
                        pending.comparison == .unknown
                    else { return nil }
                    return pending
                },
                set: { _ in }
            )
        ) { pending in
            UnknownHostPromptView(challenge: pending.challenge) { decision in
                connectionService.resolveHostKeyChallenge(decision)
            }
            .interactiveDismissDisabled()
        }
        .onChange(of: connectionService.status) { _, newStatus in
            announceStateChange(newStatus)

            if case .connected = newStatus, !usedKeychainPassword, pendingPassword != nil {
                showSavePasswordAlert = true
            }
        }
        .task {
            await initiateConnection()
        }
    }

    // MARK: - Connection Logic

    private func initiateConnection() async {
        if let password = await KeychainService.retrieve(forConnectionID: connection.id) {
            usedKeychainPassword = true
            connectWith(password: password)
        } else {
            showPasswordPrompt = true
        }
    }

    private func connectWith(password: String) {
        connectionService.connect(
            host: connection.host,
            port: connection.port,
            username: connection.username,
            password: password
        )
    }

    private func retryConnection() {
        usedKeychainPassword = false
        pendingPassword = nil
        Task {
            await initiateConnection()
        }
    }

    private func handlePasswordPromptDismiss() {
        if connectionService.status == .idle && pendingPassword == nil {
            dismiss()
        }
    }

    private func announceStateChange(_ state: ConnectionState) {
        let announcement: String? = switch state {
        case .connecting: "Connecting to server"
        case .connected: "Connected to server"
        case .failed(let message): message
        case .idle: nil
        }

        if let announcement {
            AccessibilityNotification.Announcement(announcement).post()
        }
    }
}
