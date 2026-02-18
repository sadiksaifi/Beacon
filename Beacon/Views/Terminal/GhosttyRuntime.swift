import Foundation
import os
@preconcurrency import GhosttyKit

/// Singleton that manages the global ghostty app instance.
///
/// All ghostty API calls must happen on the main thread, so this is
/// isolated to `@MainActor`. The runtime is initialised lazily on
/// first access via ``shared``.
@MainActor
final class GhosttyRuntime {

    // MARK: - Singleton

    /// The shared runtime instance. Accessing this property for the
    /// first time initialises ghostty and creates the app object.
    static let shared = GhosttyRuntime()

    // MARK: - Properties

    /// The ghostty app handle used to create surfaces.
    private(set) var app: ghostty_app_t?

    /// Whether the runtime initialised successfully.
    private(set) var isReady = false

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.beacon.app",
        category: "GhosttyRuntime"
    )

    // MARK: - Initialisation

    private init() {
        // 1. Global one-time init
        let initResult = ghostty_init(
            UInt(CommandLine.argc),
            CommandLine.unsafeArgv
        )
        guard initResult == GHOSTTY_SUCCESS else {
            Self.logger.error("ghostty_init failed with code \(initResult)")
            return
        }

        // 2. Create a minimal configuration for the embedded terminal.
        //    On iOS we skip file-based config loading and just finalise
        //    with defaults.
        guard let config = ghostty_config_new() else {
            Self.logger.error("ghostty_config_new failed")
            return
        }
        ghostty_config_finalize(config)
        defer { ghostty_config_free(config) }

        // 3. Build runtime callbacks. The userdata pointer is `self`
        //    (unretained because the singleton lives for the app lifetime).
        var runtimeConfig = ghostty_runtime_config_s(
            userdata: Unmanaged.passUnretained(self).toOpaque(),
            supports_selection_clipboard: false,
            wakeup_cb: { userdata in
                GhosttyRuntime.handleWakeup(userdata)
            },
            action_cb: { app, target, action in
                GhosttyRuntime.handleAction(app!, target: target, action: action)
            },
            read_clipboard_cb: { _, _, _ in },
            confirm_read_clipboard_cb: { _, _, _, _ in },
            write_clipboard_cb: { _, _, _, _, _ in },
            close_surface_cb: { _, _ in }
        )

        // 4. Create the app
        guard let app = ghostty_app_new(&runtimeConfig, config) else {
            Self.logger.error("ghostty_app_new failed")
            return
        }

        self.app = app
        self.isReady = true
        Self.logger.info("GhosttyRuntime initialised successfully")
    }

    // No deinit: this singleton lives for the entire app lifetime.
    // ghostty_app_free would be called here if teardown were needed,
    // but process exit handles cleanup.

    // MARK: - App tick

    /// Performs one tick of the ghostty event loop. Called from the
    /// wakeup callback to process pending work.
    func tick() {
        guard let app else { return }
        ghostty_app_tick(app)
    }

    // MARK: - Runtime callbacks

    /// Called by ghostty from any thread when new work is available.
    /// We dispatch to main to run a tick.
    private static func handleWakeup(_ userdata: UnsafeMutableRawPointer?) {
        guard let userdata else { return }
        let runtime = Unmanaged<GhosttyRuntime>.fromOpaque(userdata)
            .takeUnretainedValue()
        DispatchQueue.main.async {
            runtime.tick()
        }
    }

    /// Handles action requests from the ghostty core. For our embedded
    /// terminal we handle the render action and ignore most others.
    private static func handleAction(
        _ app: ghostty_app_t,
        target: ghostty_target_s,
        action: ghostty_action_s
    ) -> Bool {
        switch action.tag {
        case GHOSTTY_ACTION_RENDER:
            // Render is handled automatically by Metal/CAMetalLayer
            return true

        case GHOSTTY_ACTION_SET_TITLE,
             GHOSTTY_ACTION_CELL_SIZE,
             GHOSTTY_ACTION_MOUSE_SHAPE,
             GHOSTTY_ACTION_MOUSE_VISIBILITY,
             GHOSTTY_ACTION_RENDERER_HEALTH,
             GHOSTTY_ACTION_COLOR_CHANGE:
            // Acknowledged but not yet handled
            return true

        default:
            return false
        }
    }
}
