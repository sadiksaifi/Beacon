import UIKit
import QuartzCore
import os
@preconcurrency import GhosttyKit

/// A UIView backed by `CAMetalLayer` that hosts a libghostty terminal surface.
///
/// This view is responsible for:
/// - Creating and owning the `ghostty_surface_t` for rendering
/// - Forwarding layout changes (size, content scale) to the surface
/// - Exposing the slave PTY file descriptor for SSH integration
///
/// All ghostty calls must happen on the main thread, which is naturally
/// satisfied because UIView lifecycle methods run on main.
final class TerminalView: UIView {

    // MARK: - Properties

    /// The ghostty surface handle.
    ///
    /// Marked `nonisolated(unsafe)` so that `deinit` (which is nonisolated)
    /// can read the pointer to free it. Safety invariant: UIView instances
    /// are always deallocated on the main thread, and all mutations of this
    /// property happen on the main thread.
    nonisolated(unsafe) private(set) var surface: ghostty_surface_t?

    /// The slave-side file descriptor of the PTY created by ghostty.
    /// This is the FD that should be connected to the SSH channel so
    /// that remote shell I/O flows through the terminal emulator.
    nonisolated(unsafe) private(set) var ptyFileDescriptor: Int32 = -1

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.beacon.app",
        category: "TerminalView"
    )

    // MARK: - Layer class

    override class var layerClass: AnyClass {
        CAMetalLayer.self
    }

    /// Typed accessor for the Metal layer.
    private var metalLayer: CAMetalLayer {
        // swiftlint:disable:next force_cast
        layer as! CAMetalLayer
    }

    // MARK: - Initialisation

    init() {
        // Start with a reasonable default frame; the actual size will be
        // set by Auto Layout / the hosting SwiftUI representable.
        super.init(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        configureMetalLayer()
        createSurface()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported for TerminalView")
    }

    deinit {
        // Safe to access `surface` directly because it is
        // `nonisolated(unsafe)` and UIView deallocation occurs on main.
        if let surface {
            ghostty_surface_free(surface)
        }
    }

    // MARK: - Metal layer configuration

    private func configureMetalLayer() {
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.isOpaque = true
        // Match the screen scale immediately; we will update this in
        // layoutSubviews for accuracy.
        metalLayer.contentsScale = UIScreen.main.scale
    }

    // MARK: - Surface creation

    private func createSurface() {
        let runtime = GhosttyRuntime.shared
        guard runtime.isReady, let app = runtime.app else {
            Self.logger.error("GhosttyRuntime is not ready; cannot create surface")
            return
        }

        // Build the surface configuration for iOS.
        var config = ghostty_surface_config_new()
        config.platform_tag = GHOSTTY_PLATFORM_IOS
        config.platform = ghostty_platform_u(
            ios: ghostty_platform_ios_s(
                uiview: Unmanaged.passUnretained(self).toOpaque()
            )
        )
        config.userdata = Unmanaged.passUnretained(self).toOpaque()
        config.scale_factor = Double(UIScreen.main.scale)
        config.font_size = 0 // 0 = inherit from config default
        config.context = GHOSTTY_SURFACE_CONTEXT_WINDOW

        guard let surface = ghostty_surface_new(app, &config) else {
            Self.logger.error("ghostty_surface_new failed")
            return
        }

        self.surface = surface

        // Retrieve the slave PTY file descriptor.
        let fd = ghostty_surface_pty_fd(surface)
        if fd >= 0 {
            self.ptyFileDescriptor = fd
            Self.logger.info("PTY file descriptor: \(fd)")
        } else {
            Self.logger.warning("ghostty_surface_pty_fd returned \(fd)")
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        updateSurfaceSize(bounds.size)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // When the view is added to a window we get an accurate content
        // scale factor and should push the current size to the surface.
        if window != nil {
            metalLayer.contentsScale = window?.screen.scale ?? UIScreen.main.scale
            updateSurfaceSize(bounds.size)
        }
    }

    /// Notifies the ghostty surface of a size change. The size parameter
    /// is in points; we multiply by the content scale to get the pixel
    /// dimensions that the renderer needs.
    func updateSurfaceSize(_ size: CGSize) {
        guard let surface else { return }

        let scale = metalLayer.contentsScale
        ghostty_surface_set_content_scale(surface, Double(scale), Double(scale))
        ghostty_surface_set_size(
            surface,
            UInt32(size.width * scale),
            UInt32(size.height * scale)
        )
    }

    // MARK: - Focus

    /// Tells the ghostty surface whether it has focus. Call this when
    /// the terminal gains or loses user focus.
    func setFocus(_ focused: Bool) {
        guard let surface else { return }
        ghostty_surface_set_focus(surface, focused)
    }
}
