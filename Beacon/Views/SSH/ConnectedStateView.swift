import SwiftUI

/// Displayed when an SSH session is active.
/// Phase 6 will replace this placeholder with a terminal surface.
struct ConnectedStateView: View {
    let onDisconnect: () -> Void

    var body: some View {
        ContentUnavailableView {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.green)
        } description: {
            Text("Connected")
        } actions: {
            Button("Disconnect", systemImage: "xmark.circle", action: onDisconnect)
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .accessibilityLabel("Disconnect from server")
        }
    }
}
