import SwiftUI

/// SwiftUI wrapper for `TerminalView`, the Metal-backed libghostty surface.
struct TerminalSurface: UIViewRepresentable {
    /// The connection being used, for accessibility labels.
    let connection: Connection

    /// Called when the TerminalView is created, passing back the `TerminalView`
    /// so the caller can access `ptyFileDescriptor` and set up the I/O bridge.
    let onSurfaceReady: (TerminalView) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> TerminalView {
        let view = TerminalView()
        view.setFocus(true)

        // Configure accessibility
        view.isAccessibilityElement = true
        view.accessibilityLabel = "Terminal — connected to \(connection.host)"
        view.accessibilityTraits = .allowsDirectInteraction

        // Wire up the coordinator so it can drive size updates on this view.
        context.coordinator.terminalView = view
        context.coordinator.startObserving()

        // Notify the parent that the surface is ready
        onSurfaceReady(view)

        return view
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {
        // Update accessibility label if connection info changes
        uiView.accessibilityLabel = "Terminal — connected to \(connection.host)"
    }

    static func dismantleUIView(_ uiView: TerminalView, coordinator: Coordinator) {
        coordinator.stopObserving()
    }

    // MARK: - Coordinator

    /// Manages keyboard frame observations and drives terminal resize
    /// animations that match the keyboard show/hide animation curve.
    final class Coordinator {
        /// Weak reference to the hosted view; set immediately after creation.
        weak var terminalView: TerminalView?

        private var keyboardObservers: [Any] = []

        func startObserving() {
            let observer = NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillChangeFrameNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleKeyboardChange(notification)
            }
            keyboardObservers = [observer]
        }

        func stopObserving() {
            keyboardObservers.forEach {
                NotificationCenter.default.removeObserver($0)
            }
            keyboardObservers = []
        }

        private func handleKeyboardChange(_ notification: Notification) {
            guard
                let terminalView,
                let userInfo = notification.userInfo,
                let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                let window = terminalView.window
            else { return }

            // Convert the keyboard's end frame (expressed in screen coordinates)
            // into the terminal view's own coordinate space so we can calculate
            // how much of the view it overlaps.
            let keyboardFrameInView = terminalView.convert(
                endFrame,
                from: window.screen.coordinateSpace
            )
            let overlap = terminalView.bounds.intersection(keyboardFrameInView)

            // Subtract only the overlapping portion so that a floating or
            // undocked keyboard (which may not intersect the view at all)
            // leaves the terminal at full size.
            let availableHeight = terminalView.bounds.height
                - (overlap.isNull ? 0 : overlap.height)

            // Never shrink the terminal below a sensible minimum so that the
            // ghostty surface always has a valid, positive-sized canvas.
            let availableSize = CGSize(
                width: terminalView.bounds.width,
                height: max(availableHeight, 100)
            )

            // Read animation parameters from the notification so our resize
            // animation is perfectly synchronised with the keyboard.
            let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey]
                as? TimeInterval ?? 0.25
            let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey]
                as? UInt ?? 7
            // UIKit encodes the animation curve in the upper bits of the options bitmask.
            let options = UIView.AnimationOptions(rawValue: curveValue << 16)

            UIView.animate(withDuration: duration, delay: 0, options: options) {
                terminalView.updateSurfaceSize(availableSize)
            }
        }
    }
}
