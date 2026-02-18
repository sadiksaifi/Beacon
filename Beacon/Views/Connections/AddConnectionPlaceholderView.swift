import SwiftUI

struct AddConnectionPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Coming Soon", systemImage: "hammer")
            } description: {
                Text("Connection configuration will be available in Phase 1.")
            }
            .navigationTitle("Add Connection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AddConnectionPlaceholderView()
}
