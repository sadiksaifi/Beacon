import SwiftData
import SwiftUI

/// A form for creating or editing an SSH connection.
struct ConnectionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// The existing connection being edited, or `nil` when adding a new one.
    private var existingConnection: Connection?

    @State private var label: String
    @State private var host: String
    @State private var port: Int
    @State private var username: String
    @State private var authMethod: AuthMethod

    private var isEditing: Bool { existingConnection != nil }

    private var isHostValid: Bool { !host.trimmingCharacters(in: .whitespaces).isEmpty }
    private var isUsernameValid: Bool { !username.trimmingCharacters(in: .whitespaces).isEmpty }
    private var isPortValid: Bool { (1...65535).contains(port) }
    private var isFormValid: Bool { isHostValid && isUsernameValid && isPortValid }

    /// Creates a form for adding a new connection.
    init() {
        self.existingConnection = nil
        _label = State(initialValue: "")
        _host = State(initialValue: "")
        _port = State(initialValue: 22)
        _username = State(initialValue: "")
        _authMethod = State(initialValue: .password)
    }

    /// Creates a form for editing an existing connection.
    init(connection: Connection) {
        self.existingConnection = connection
        _label = State(initialValue: connection.label)
        _host = State(initialValue: connection.host)
        _port = State(initialValue: connection.port)
        _username = State(initialValue: connection.username)
        _authMethod = State(initialValue: connection.authMethod)
    }

    var body: some View {
        NavigationStack {
            Form {
                connectionDetailsSection
                authenticationSection
            }
            .navigationTitle(isEditing ? "Edit Connection" : "Add Connection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!isFormValid)
                }
            }
        }
    }
}

// MARK: - Form Sections

private extension ConnectionFormView {
    var connectionDetailsSection: some View {
        Section("Connection Details") {
            TextField("Label (optional)", text: $label)
                .accessibilityLabel("Connection label")

            TextField("Host", text: $host)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityLabel("Host address")

            if !host.isEmpty && !isHostValid {
                Text("Host is required.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            TextField("Port", value: $port, format: .number)
                .keyboardType(.numberPad)
                .accessibilityLabel("Port number")

            if !isPortValid {
                Text("Port must be between 1 and 65,535.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            TextField("Username", text: $username)
                .textContentType(.username)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityLabel("Username")

            if !username.isEmpty && !isUsernameValid {
                Text("Username is required.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    var authenticationSection: some View {
        Section("Authentication") {
            Picker("Method", selection: $authMethod) {
                Text("Password").tag(AuthMethod.password)
                Text("SSH Key").tag(AuthMethod.key)
            }
            .accessibilityLabel("Authentication method")
        }
    }
}

// MARK: - Actions

private extension ConnectionFormView {
    func save() {
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)

        if let existingConnection {
            existingConnection.label = label
            existingConnection.host = trimmedHost
            existingConnection.port = port
            existingConnection.username = trimmedUsername
            existingConnection.authMethod = authMethod
        } else {
            let connection = Connection(
                label: label,
                host: trimmedHost,
                port: port,
                username: trimmedUsername,
                authMethod: authMethod
            )
            modelContext.insert(connection)
        }

        dismiss()
    }
}

#Preview("Add") {
    ConnectionFormView()
        .modelContainer(for: Connection.self, inMemory: true)
}
