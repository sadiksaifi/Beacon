import SwiftUI

/// Displayed while an SSH handshake is in progress.
struct ConnectingStateView: View {
    var body: some View {
        ContentUnavailableView {
            ProgressView()
                .controlSize(.large)
        } description: {
            Text("Connecting…")
        }
    }
}
