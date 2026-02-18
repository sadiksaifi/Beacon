import SwiftUI

/// SwiftUI wrapper for `TerminalView`, the Metal-backed libghostty surface.
struct TerminalSurface: UIViewRepresentable {
    /// The connection being used, for accessibility labels.
    let connection: Connection

    /// Called when the TerminalView is created, passing back the `TerminalView`
    /// so the caller can access `ptyFileDescriptor` and set up the I/O bridge.
    let onSurfaceReady: (TerminalView) -> Void

    func makeUIView(context: Context) -> TerminalView {
        let view = TerminalView()
        view.setFocus(true)

        // Configure accessibility
        view.isAccessibilityElement = true
        view.accessibilityLabel = "Terminal — connected to \(connection.host)"
        view.accessibilityTraits = .allowsDirectInteraction

        // Notify the parent that the surface is ready
        onSurfaceReady(view)

        return view
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {
        // Update accessibility label if connection info changes
        uiView.accessibilityLabel = "Terminal — connected to \(connection.host)"
    }
}
