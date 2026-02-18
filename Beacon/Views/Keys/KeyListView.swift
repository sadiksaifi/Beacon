import SwiftUI

/// Displays all stored SSH keys and provides actions to generate or import new ones.
struct KeyListView: View {
    @Environment(SSHKeyStore.self) private var keyStore

    @State private var showGenerateSheet = false
    @State private var showImportSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if keyStore.entries.isEmpty {
                    ContentUnavailableView(
                        "No SSH Keys",
                        systemImage: "key",
                        description: Text("Generate or import an SSH key to get started.")
                    )
                } else {
                    KeyEntryList(
                        entries: keyStore.entries,
                        onDelete: deleteEntries
                    )
                }
            }
            .navigationTitle("Keys")
            .navigationDestination(for: SSHKeyEntry.self) { entry in
                PublicKeyDisplayView(entry: entry)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu("Add", systemImage: "plus") {
                        Button("Generate Key", systemImage: "wand.and.stars.inverse") {
                            showGenerateSheet = true
                        }

                        Button("Import Key", systemImage: "square.and.arrow.down") {
                            showImportSheet = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showGenerateSheet) {
                KeyGenerationView()
            }
            .sheet(isPresented: $showImportSheet) {
                Text("TODO")
            }
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            keyStore.delete(id: keyStore.entries[index].id)
        }
    }
}

// MARK: - Key Entry List

/// Renders the scrollable list of SSH key entries with swipe-to-delete support.
private struct KeyEntryList: View {
    let entries: [SSHKeyEntry]
    let onDelete: (IndexSet) -> Void

    var body: some View {
        List {
            ForEach(entries) { entry in
                NavigationLink(value: entry) {
                    KeyEntryRow(entry: entry)
                }
            }
            .onDelete(perform: onDelete)
        }
    }
}

// MARK: - Key Entry Row

/// A single row displaying the key label and algorithm type.
private struct KeyEntryRow: View {
    let entry: SSHKeyEntry

    var body: some View {
        VStack(alignment: .leading) {
            Text(entry.label)
                .font(.headline)

            Text(entry.keyType.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.label), \(entry.keyType.displayName)")
    }
}

#Preview("With Keys") {
    KeyListView()
        .environment(SSHKeyStore())
}

#Preview("Empty") {
    KeyListView()
        .environment(SSHKeyStore())
}
