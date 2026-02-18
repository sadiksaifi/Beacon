import SwiftUI

struct ConnectionsView: View {
    @State private var isAddConnectionPresented = false

    var body: some View {
        NavigationStack {
            ConnectionsEmptyStateView {
                isAddConnectionPresented = true
            }
            .navigationTitle("Connections")
            .sheet(isPresented: $isAddConnectionPresented) {
                AddConnectionPlaceholderView()
            }
        }
    }
}

#Preview {
    ConnectionsView()
}
