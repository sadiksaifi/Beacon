import SwiftData
import SwiftUI

struct ConnectionsView: View {
    @Query private var connections: [Connection]

    @State private var connectionToEdit: Connection?
    @State private var isAddingConnection = false
    @State private var connectionService = SSHConnectionService()

    var body: some View {
        NavigationStack {
            Group {
                if connections.isEmpty {
                    ConnectionsEmptyStateView {
                        isAddingConnection = true
                    }
                } else {
                    ConnectionListView(connectionToEdit: $connectionToEdit)
                }
            }
            .navigationTitle("Connections")
            .navigationDestination(for: Connection.self) { connection in
                SSHSessionView(connection: connection)
            }
            .toolbar {
                if !connections.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Add Connection", systemImage: "plus") {
                            isAddingConnection = true
                        }
                        .accessibilityLabel("Add new connection")
                    }
                }
            }
            .sheet(isPresented: $isAddingConnection) {
                ConnectionFormView()
            }
            .sheet(item: $connectionToEdit) { connection in
                ConnectionFormView(connection: connection)
            }
        }
        .environment(connectionService)
    }
}

#Preview {
    ConnectionsView()
        .modelContainer(for: Connection.self, inMemory: true)
}
