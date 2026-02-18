import SwiftUI

/// Modal sheet presenting a secure text field for password entry.
struct PasswordPromptView: View {
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @State private var password = ""
    @FocusState private var isPasswordFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Password", text: $password)
                        .focused($isPasswordFieldFocused)
                        .submitLabel(.go)
                        .onSubmit(submit)
                        .accessibilityLabel("Enter SSH password")
                }
            }
            .navigationTitle("Enter Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Connect", action: submit)
                        .disabled(password.isEmpty)
                        .bold()
                }
            }
            .onAppear {
                isPasswordFieldFocused = true
            }
        }
        .presentationDetents([.medium])
    }

    private func submit() {
        guard !password.isEmpty else { return }
        onSubmit(password)
    }
}
