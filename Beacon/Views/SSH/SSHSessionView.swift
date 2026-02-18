import Accessibility
import SwiftUI

/// Manages the SSH session lifecycle for a given connection.
///
/// On appearance, checks Keychain for a stored password. If found, connects
/// directly. If not, presents a password prompt sheet.
/// When connected, displays the terminal surface backed by libghostty and
/// bridges I/O between the SSH channel and the terminal emulator.
struct SSHSessionView: View {
    @Environment(SSHConnectionService.self) private var connectionService
    @Environment(SSHKeyStore.self) private var keyStore
    @Environment(\.dismiss) private var dismiss

    let connection: Connection

    @State private var ioBridge = TerminalIOBridge()
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
                TerminalSurface(connection: connection) { terminalView in
                    startIOBridge(terminalView: terminalView)
                }

            case .failed(let message):
                FailedStateView(message: message) {
                    retryConnection()
                }
            }
        }
        .navigationTitle(connection.label.isEmpty ? connection.host : connection.label)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(
            connectionService.status == .connecting || connectionService.status == .connected
        )
        .toolbar {
            if connectionService.status == .connecting {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        connectionService.cancel()
                        dismiss()
                    }
                }
            }
            if connectionService.status == .connected {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Disconnect", systemImage: "xmark.circle") {
                        disconnectSession()
                    }
                    .accessibilityLabel("Disconnect from server")
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
        .sheet(
            item: Binding<PendingHostKeyChallenge?>(
                get: {
                    guard let pending = connectionService.pendingHostKeyChallenge,
                        pending.comparison == .mismatch
                    else { return nil }
                    return pending
                },
                set: { _ in }
            )
        ) { pending in
            MismatchWarningView(
                challenge: pending.challenge,
                storedFingerprint: pending.storedFingerprint ?? ""
            ) { decision in
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
        .onChange(of: ioBridge.status) { _, newBridgeStatus in
            handleBridgeStatusChange(newBridgeStatus)
        }
        .onDisappear {
            ioBridge.stop()
        }
        .task {
            await initiateConnection()
        }
    }

    // MARK: - Connection Logic

    private func initiateConnection() async {
        switch connection.authMethod {
        case .password:
            if let password = await KeychainService.retrieve(forConnectionID: connection.id) {
                usedKeychainPassword = true
                connectWith(password: password)
            } else {
                showPasswordPrompt = true
            }
        case .key:
            await initiateKeyConnection()
        }
    }

    private func initiateKeyConnection() async {
        guard let keyID = connection.selectedKeyID,
              let entry = keyStore.entries.first(where: { $0.id == keyID })
        else {
            connectionService.fail(message: "SSH key not found. It may have been deleted.")
            return
        }

        guard let privateKeyData = await keyStore.retrieve(keychainID: entry.keychainID) else {
            connectionService.fail(message: "Authentication cancelled")
            return
        }

        connectionService.connect(
            host: connection.host,
            port: connection.port,
            username: connection.username,
            privateKeyData: privateKeyData,
            keyType: entry.keyType
        )
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
        ioBridge.stop()
        ioBridge = TerminalIOBridge()
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

    // MARK: - I/O Bridge

    /// Starts the I/O bridge between the SSH client and the terminal emulator.
    ///
    /// Called by `TerminalSurface` once the ghostty surface and PTY file
    /// descriptor are ready. The bridge relays data bidirectionally between
    /// the SSH channel and the terminal's PTY.
    private func startIOBridge(terminalView: TerminalView) {
        guard let client = connectionService.client else { return }
        ioBridge.start(
            client: client,
            ptyFD: terminalView.ptyFileDescriptor
        )
    }

    /// Responds to I/O bridge status changes.
    ///
    /// When the bridge starts running, announces the session is active for
    /// VoiceOver users. When the bridge disconnects or encounters an error,
    /// the session view transitions to the failed state so the user sees
    /// feedback instead of a frozen terminal.
    private func handleBridgeStatusChange(_ newStatus: TerminalIOBridge.Status) {
        switch newStatus {
        case .running:
            AccessibilityNotification.Announcement("Terminal session started").post()
        case .disconnected(let reason):
            guard connectionService.status == .connected else { return }
            connectionService.fail(message: "Connection lost: \(reason)")
        case .error(let message):
            guard connectionService.status == .connected else { return }
            connectionService.fail(message: message)
        case .idle:
            break
        }
    }

    /// Stops the I/O bridge and disconnects the SSH session.
    private func disconnectSession() {
        ioBridge.stop()
        Task {
            await connectionService.disconnect()
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
