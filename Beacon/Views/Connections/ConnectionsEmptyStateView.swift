import SwiftUI

struct ConnectionsEmptyStateView: View {
    var onAddConnection: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Connections", systemImage: "network.slash")
        } description: {
            Text("Add your first SSH connection to get started.")
        } actions: {
            Button("Add Connection", systemImage: "plus", action: onAddConnection)
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Add your first connection")
        }
    }
}

#Preview {
    ConnectionsEmptyStateView(onAddConnection: {})
}
