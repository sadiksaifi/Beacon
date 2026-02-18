import SwiftData
import SwiftUI

/// Displays all saved connections in a scrollable list.
///
/// Tapping a row navigates to `SSHSessionView` (connect).
/// Swipe actions provide Edit and Delete.
struct ConnectionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Connection.label) private var connections: [Connection]

    @Binding var connectionToEdit: Connection?

    var body: some View {
        List {
            ForEach(connections) { connection in
                NavigationLink(value: connection) {
                    ConnectionRow(connection: connection)
                }
                .accessibilityHint("Double tap to connect")
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        delete(connection)
                    }
                    .accessibilityLabel("Delete connection")
                }
                .swipeActions(edge: .trailing) {
                    Button("Edit", systemImage: "pencil") {
                        connectionToEdit = connection
                    }
                    .tint(.orange)
                    .accessibilityLabel("Edit connection")
                }
            }
        }
    }

    private func delete(_ connection: Connection) {
        modelContext.delete(connection)
    }
}

// MARK: - Row

private struct ConnectionRow: View {
    let connection: Connection

    private var displayName: String {
        connection.label.isEmpty ? connection.host : connection.label
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(displayName)
                .font(.headline)

            Text("\(connection.username)@\(connection.host):\(connection.port)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayName), \(connection.username) at \(connection.host) port \(connection.port)")
    }
}
