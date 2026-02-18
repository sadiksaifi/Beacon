import SwiftData
import SwiftUI

/// Displays all saved connections in a scrollable list.
struct ConnectionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Connection.label) private var connections: [Connection]

    @Binding var selectedConnection: Connection?

    var body: some View {
        List {
            ForEach(connections) { connection in
                ConnectionRow(connection: connection)
                    .contentShape(.rect)
                    .onTapGesture {
                        selectedConnection = connection
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            delete(connection)
                        }
                        .accessibilityLabel("Delete connection")
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
