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
final class TerminalView: UIView, UIKeyInput {

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

    // MARK: - First responder

    override var canBecomeFirstResponder: Bool { true }

    // MARK: - UITextInputTraits

    /// Disable autocorrection for terminal input.
    var autocorrectionType: UITextAutocorrectionType = .no

    /// Disable autocapitalisation for terminal input.
    var autocapitalizationType: UITextAutocapitalizationType = .none

    /// Disable smart quotes, dashes, and other text replacements.
    var smartQuotesType: UITextSmartQuotesType = .no
    var smartDashesType: UITextSmartDashesType = .no
    var smartInsertDeleteType: UITextSmartInsertDeleteType = .no
    var spellCheckingType: UITextSpellCheckingType = .no

    /// Use the default keyboard but allow all character types.
    var keyboardType: UIKeyboardType = .default

    // MARK: - UIKeyInput

    /// Always report that we have text so the keyboard never dismisses
    /// the backspace key.
    var hasText: Bool { true }

    /// Delivers typed text from the iOS software keyboard to the
    /// ghostty terminal surface.
    ///
    /// For regular printable text we use `ghostty_surface_text()` which
    /// writes raw bytes to the PTY. For newline (Return key) we send a
    /// proper key event with `GHOSTTY_KEY_ENTER` so that the terminal
    /// emulator can process it correctly (e.g. for key encoding modes).
    func insertText(_ text: String) {
        guard let surface else { return }

        // The software keyboard sends "\n" for the Return key.
        if text == "\n" {
            sendKeyEvent(key: GHOSTTY_KEY_ENTER, keyCode: 0x0024)
            return
        }

        // The software keyboard sends "\t" for the Tab key.
        if text == "\t" {
            sendKeyEvent(key: GHOSTTY_KEY_TAB, keyCode: 0x0030)
            return
        }

        // For all other text, send it directly as raw text. This is the
        // same approach Ghostty uses in its `sendText` method — it handles
        // Unicode correctly and avoids needing to map each character to
        // a key code.
        let len = text.utf8CString.count
        guard len > 0 else { return }
        text.withCString { ptr in
            // len includes the null terminator so we subtract 1.
            ghostty_surface_text(surface, ptr, UInt(len - 1))
        }
    }

    /// Delivers a backspace key event to the ghostty terminal surface.
    func deleteBackward() {
        sendKeyEvent(key: GHOSTTY_KEY_BACKSPACE, keyCode: 0x0033)
    }

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

        // Become first responder on the next run loop iteration so
        // the view hierarchy is fully set up and the keyboard appears.
        Task { @MainActor [weak self] in
            self?.becomeFirstResponder()
        }
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

    // MARK: - Hardware keyboard support

    /// Handles physical key presses from a hardware keyboard (e.g. Smart
    /// Keyboard, Magic Keyboard). Maps `UIPress` key codes to ghostty
    /// key events so that arrow keys, escape, function keys, and modifier
    /// combinations all work correctly.
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false

        for press in presses {
            guard let uiKey = press.key else { continue }

            if let ghosttyKey = Self.uiKeyCodeToGhosttyKey[uiKey.keyCode] {
                let mods = Self.ghosttyMods(from: uiKey.modifierFlags)
                let keyCode = Self.ghosttyKeyToMacKeyCode[ghosttyKey] ?? 0

                // For printable characters we include the text so the
                // terminal can encode it properly (e.g. shifted symbols).
                let characters = uiKey.characters
                let text: String? = if !characters.isEmpty,
                    let scalar = characters.unicodeScalars.first,
                    scalar.value >= 0x20 {
                    characters
                } else {
                    nil
                }

                sendKeyEvent(
                    key: ghosttyKey,
                    keyCode: keyCode,
                    action: GHOSTTY_ACTION_PRESS,
                    mods: mods,
                    text: text
                )
                handled = true
            }
        }

        if !handled {
            super.pressesBegan(presses, with: event)
        }
    }

    /// Handles physical key releases from a hardware keyboard.
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false

        for press in presses {
            guard let uiKey = press.key else { continue }

            if let ghosttyKey = Self.uiKeyCodeToGhosttyKey[uiKey.keyCode] {
                let mods = Self.ghosttyMods(from: uiKey.modifierFlags)
                let keyCode = Self.ghosttyKeyToMacKeyCode[ghosttyKey] ?? 0

                sendKeyEvent(
                    key: ghosttyKey,
                    keyCode: keyCode,
                    action: GHOSTTY_ACTION_RELEASE,
                    mods: mods
                )
                handled = true
            }
        }

        if !handled {
            super.pressesEnded(presses, with: event)
        }
    }

    /// Handles cancelled key presses (e.g. system gesture interruption).
    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        // Treat cancelled presses the same as ended — release any held keys.
        pressesEnded(presses, with: event)
    }

    // MARK: - Key event helpers

    /// Sends a ghostty key event for a special key (enter, backspace, tab,
    /// arrow keys, etc.) with both PRESS and RELEASE actions.
    ///
    /// - Parameters:
    ///   - key: The ghostty key enum value.
    ///   - keyCode: The macOS-style key code used by ghostty internally.
    ///   - action: The key action (defaults to sending both press and release).
    ///   - mods: Modifier flags for the key event.
    ///   - text: Optional text associated with the key event.
    private func sendKeyEvent(
        key: ghostty_input_key_e,
        keyCode: UInt32,
        action: ghostty_input_action_e? = nil,
        mods: ghostty_input_mods_e = GHOSTTY_MODS_NONE,
        text: String? = nil
    ) {
        guard let surface else { return }

        // Build the base key event struct.
        var keyEvent = ghostty_input_key_s()
        keyEvent.keycode = keyCode
        keyEvent.mods = mods
        keyEvent.consumed_mods = GHOSTTY_MODS_NONE
        keyEvent.composing = false
        keyEvent.unshifted_codepoint = 0

        if let action {
            // Single action (used by hardware keyboard press/release).
            keyEvent.action = action

            if let text {
                text.withCString { ptr in
                    keyEvent.text = ptr
                    ghostty_surface_key(surface, keyEvent)
                }
            } else {
                keyEvent.text = nil
                ghostty_surface_key(surface, keyEvent)
            }
        } else {
            // No explicit action — send both PRESS and RELEASE (used by
            // software keyboard which only gives us a single event).
            keyEvent.text = nil

            // Press
            keyEvent.action = GHOSTTY_ACTION_PRESS
            ghostty_surface_key(surface, keyEvent)

            // Release
            keyEvent.action = GHOSTTY_ACTION_RELEASE
            ghostty_surface_key(surface, keyEvent)
        }
    }

    // MARK: - Modifier translation

    /// Converts UIKit modifier flags to the equivalent ghostty modifier
    /// bitmask.
    private static func ghosttyMods(
        from flags: UIKeyModifierFlags
    ) -> ghostty_input_mods_e {
        var mods: UInt32 = GHOSTTY_MODS_NONE.rawValue

        if flags.contains(.shift) { mods |= GHOSTTY_MODS_SHIFT.rawValue }
        if flags.contains(.control) { mods |= GHOSTTY_MODS_CTRL.rawValue }
        if flags.contains(.alternate) { mods |= GHOSTTY_MODS_ALT.rawValue }
        if flags.contains(.command) { mods |= GHOSTTY_MODS_SUPER.rawValue }
        if flags.contains(.alphaShift) { mods |= GHOSTTY_MODS_CAPS.rawValue }

        return ghostty_input_mods_e(mods)
    }

    // MARK: - Key code mappings

    /// Maps `UIKeyboardHIDUsage` codes to ghostty key enums. This covers
    /// the keys most commonly used in a terminal that need special
    /// handling beyond simple text insertion.
    private static let uiKeyCodeToGhosttyKey: [UIKeyboardHIDUsage: ghostty_input_key_e] = [
        // Letters
        .keyboardA: GHOSTTY_KEY_A,
        .keyboardB: GHOSTTY_KEY_B,
        .keyboardC: GHOSTTY_KEY_C,
        .keyboardD: GHOSTTY_KEY_D,
        .keyboardE: GHOSTTY_KEY_E,
        .keyboardF: GHOSTTY_KEY_F,
        .keyboardG: GHOSTTY_KEY_G,
        .keyboardH: GHOSTTY_KEY_H,
        .keyboardI: GHOSTTY_KEY_I,
        .keyboardJ: GHOSTTY_KEY_J,
        .keyboardK: GHOSTTY_KEY_K,
        .keyboardL: GHOSTTY_KEY_L,
        .keyboardM: GHOSTTY_KEY_M,
        .keyboardN: GHOSTTY_KEY_N,
        .keyboardO: GHOSTTY_KEY_O,
        .keyboardP: GHOSTTY_KEY_P,
        .keyboardQ: GHOSTTY_KEY_Q,
        .keyboardR: GHOSTTY_KEY_R,
        .keyboardS: GHOSTTY_KEY_S,
        .keyboardT: GHOSTTY_KEY_T,
        .keyboardU: GHOSTTY_KEY_U,
        .keyboardV: GHOSTTY_KEY_V,
        .keyboardW: GHOSTTY_KEY_W,
        .keyboardX: GHOSTTY_KEY_X,
        .keyboardY: GHOSTTY_KEY_Y,
        .keyboardZ: GHOSTTY_KEY_Z,

        // Digits
        .keyboard0: GHOSTTY_KEY_DIGIT_0,
        .keyboard1: GHOSTTY_KEY_DIGIT_1,
        .keyboard2: GHOSTTY_KEY_DIGIT_2,
        .keyboard3: GHOSTTY_KEY_DIGIT_3,
        .keyboard4: GHOSTTY_KEY_DIGIT_4,
        .keyboard5: GHOSTTY_KEY_DIGIT_5,
        .keyboard6: GHOSTTY_KEY_DIGIT_6,
        .keyboard7: GHOSTTY_KEY_DIGIT_7,
        .keyboard8: GHOSTTY_KEY_DIGIT_8,
        .keyboard9: GHOSTTY_KEY_DIGIT_9,

        // Punctuation & symbols
        .keyboardHyphen: GHOSTTY_KEY_MINUS,
        .keyboardEqualSign: GHOSTTY_KEY_EQUAL,
        .keyboardOpenBracket: GHOSTTY_KEY_BRACKET_LEFT,
        .keyboardCloseBracket: GHOSTTY_KEY_BRACKET_RIGHT,
        .keyboardBackslash: GHOSTTY_KEY_BACKSLASH,
        .keyboardSemicolon: GHOSTTY_KEY_SEMICOLON,
        .keyboardQuote: GHOSTTY_KEY_QUOTE,
        .keyboardGraveAccentAndTilde: GHOSTTY_KEY_BACKQUOTE,
        .keyboardComma: GHOSTTY_KEY_COMMA,
        .keyboardPeriod: GHOSTTY_KEY_PERIOD,
        .keyboardSlash: GHOSTTY_KEY_SLASH,

        // Functional keys
        .keyboardReturnOrEnter: GHOSTTY_KEY_ENTER,
        .keyboardEscape: GHOSTTY_KEY_ESCAPE,
        .keyboardDeleteOrBackspace: GHOSTTY_KEY_BACKSPACE,
        .keyboardTab: GHOSTTY_KEY_TAB,
        .keyboardSpacebar: GHOSTTY_KEY_SPACE,
        .keyboardDeleteForward: GHOSTTY_KEY_DELETE,
        .keyboardCapsLock: GHOSTTY_KEY_CAPS_LOCK,

        // Arrow keys
        .keyboardUpArrow: GHOSTTY_KEY_ARROW_UP,
        .keyboardDownArrow: GHOSTTY_KEY_ARROW_DOWN,
        .keyboardLeftArrow: GHOSTTY_KEY_ARROW_LEFT,
        .keyboardRightArrow: GHOSTTY_KEY_ARROW_RIGHT,

        // Navigation
        .keyboardHome: GHOSTTY_KEY_HOME,
        .keyboardEnd: GHOSTTY_KEY_END,
        .keyboardPageUp: GHOSTTY_KEY_PAGE_UP,
        .keyboardPageDown: GHOSTTY_KEY_PAGE_DOWN,
        .keyboardInsert: GHOSTTY_KEY_INSERT,

        // Function keys
        .keyboardF1: GHOSTTY_KEY_F1,
        .keyboardF2: GHOSTTY_KEY_F2,
        .keyboardF3: GHOSTTY_KEY_F3,
        .keyboardF4: GHOSTTY_KEY_F4,
        .keyboardF5: GHOSTTY_KEY_F5,
        .keyboardF6: GHOSTTY_KEY_F6,
        .keyboardF7: GHOSTTY_KEY_F7,
        .keyboardF8: GHOSTTY_KEY_F8,
        .keyboardF9: GHOSTTY_KEY_F9,
        .keyboardF10: GHOSTTY_KEY_F10,
        .keyboardF11: GHOSTTY_KEY_F11,
        .keyboardF12: GHOSTTY_KEY_F12,

        // Modifier keys (for flagsChanged-like behavior)
        .keyboardLeftShift: GHOSTTY_KEY_SHIFT_LEFT,
        .keyboardRightShift: GHOSTTY_KEY_SHIFT_RIGHT,
        .keyboardLeftControl: GHOSTTY_KEY_CONTROL_LEFT,
        .keyboardRightControl: GHOSTTY_KEY_CONTROL_RIGHT,
        .keyboardLeftAlt: GHOSTTY_KEY_ALT_LEFT,
        .keyboardRightAlt: GHOSTTY_KEY_ALT_RIGHT,
        .keyboardLeftGUI: GHOSTTY_KEY_META_LEFT,
        .keyboardRightGUI: GHOSTTY_KEY_META_RIGHT,

        // Numpad
        .keypad0: GHOSTTY_KEY_NUMPAD_0,
        .keypad1: GHOSTTY_KEY_NUMPAD_1,
        .keypad2: GHOSTTY_KEY_NUMPAD_2,
        .keypad3: GHOSTTY_KEY_NUMPAD_3,
        .keypad4: GHOSTTY_KEY_NUMPAD_4,
        .keypad5: GHOSTTY_KEY_NUMPAD_5,
        .keypad6: GHOSTTY_KEY_NUMPAD_6,
        .keypad7: GHOSTTY_KEY_NUMPAD_7,
        .keypad8: GHOSTTY_KEY_NUMPAD_8,
        .keypad9: GHOSTTY_KEY_NUMPAD_9,
        .keypadPlus: GHOSTTY_KEY_NUMPAD_ADD,
        .keypadHyphen: GHOSTTY_KEY_NUMPAD_SUBTRACT,
        .keypadAsterisk: GHOSTTY_KEY_NUMPAD_MULTIPLY,
        .keypadSlash: GHOSTTY_KEY_NUMPAD_DIVIDE,
        .keypadPeriod: GHOSTTY_KEY_NUMPAD_DECIMAL,
        .keypadEnter: GHOSTTY_KEY_NUMPAD_ENTER,
        .keypadEqualSign: GHOSTTY_KEY_NUMPAD_EQUAL,
        .keypadNumLock: GHOSTTY_KEY_NUM_LOCK,
    ]

    /// Maps ghostty key enums to macOS key codes, which ghostty uses
    /// internally for key identification. These values match the key
    /// codes defined in Ghostty's `src/input/keycodes.zig`.
    private static let ghosttyKeyToMacKeyCode: [ghostty_input_key_e: UInt32] = [
        // Letters
        GHOSTTY_KEY_A: 0x0000,
        GHOSTTY_KEY_B: 0x000b,
        GHOSTTY_KEY_C: 0x0008,
        GHOSTTY_KEY_D: 0x0002,
        GHOSTTY_KEY_E: 0x000e,
        GHOSTTY_KEY_F: 0x0003,
        GHOSTTY_KEY_G: 0x0005,
        GHOSTTY_KEY_H: 0x0004,
        GHOSTTY_KEY_I: 0x0022,
        GHOSTTY_KEY_J: 0x0026,
        GHOSTTY_KEY_K: 0x0028,
        GHOSTTY_KEY_L: 0x0025,
        GHOSTTY_KEY_M: 0x002e,
        GHOSTTY_KEY_N: 0x002d,
        GHOSTTY_KEY_O: 0x001f,
        GHOSTTY_KEY_P: 0x0023,
        GHOSTTY_KEY_Q: 0x000c,
        GHOSTTY_KEY_R: 0x000f,
        GHOSTTY_KEY_S: 0x0001,
        GHOSTTY_KEY_T: 0x0011,
        GHOSTTY_KEY_U: 0x0020,
        GHOSTTY_KEY_V: 0x0009,
        GHOSTTY_KEY_W: 0x000d,
        GHOSTTY_KEY_X: 0x0007,
        GHOSTTY_KEY_Y: 0x0010,
        GHOSTTY_KEY_Z: 0x0006,

        // Digits
        GHOSTTY_KEY_DIGIT_0: 0x001d,
        GHOSTTY_KEY_DIGIT_1: 0x0012,
        GHOSTTY_KEY_DIGIT_2: 0x0013,
        GHOSTTY_KEY_DIGIT_3: 0x0014,
        GHOSTTY_KEY_DIGIT_4: 0x0015,
        GHOSTTY_KEY_DIGIT_5: 0x0017,
        GHOSTTY_KEY_DIGIT_6: 0x0016,
        GHOSTTY_KEY_DIGIT_7: 0x001a,
        GHOSTTY_KEY_DIGIT_8: 0x001c,
        GHOSTTY_KEY_DIGIT_9: 0x0019,

        // Punctuation & symbols
        GHOSTTY_KEY_MINUS: 0x001b,
        GHOSTTY_KEY_EQUAL: 0x0018,
        GHOSTTY_KEY_BRACKET_LEFT: 0x0021,
        GHOSTTY_KEY_BRACKET_RIGHT: 0x001e,
        GHOSTTY_KEY_BACKSLASH: 0x002a,
        GHOSTTY_KEY_SEMICOLON: 0x0029,
        GHOSTTY_KEY_QUOTE: 0x0027,
        GHOSTTY_KEY_BACKQUOTE: 0x0032,
        GHOSTTY_KEY_COMMA: 0x002b,
        GHOSTTY_KEY_PERIOD: 0x002f,
        GHOSTTY_KEY_SLASH: 0x002c,

        // Functional keys
        GHOSTTY_KEY_ENTER: 0x0024,
        GHOSTTY_KEY_ESCAPE: 0x0035,
        GHOSTTY_KEY_BACKSPACE: 0x0033,
        GHOSTTY_KEY_TAB: 0x0030,
        GHOSTTY_KEY_SPACE: 0x0031,
        GHOSTTY_KEY_DELETE: 0x0075,
        GHOSTTY_KEY_CAPS_LOCK: 0x0039,

        // Arrow keys
        GHOSTTY_KEY_ARROW_UP: 0x007e,
        GHOSTTY_KEY_ARROW_DOWN: 0x007d,
        GHOSTTY_KEY_ARROW_LEFT: 0x007b,
        GHOSTTY_KEY_ARROW_RIGHT: 0x007c,

        // Navigation
        GHOSTTY_KEY_HOME: 0x0073,
        GHOSTTY_KEY_END: 0x0077,
        GHOSTTY_KEY_PAGE_UP: 0x0074,
        GHOSTTY_KEY_PAGE_DOWN: 0x0079,
        GHOSTTY_KEY_INSERT: 0x0072,

        // Function keys
        GHOSTTY_KEY_F1: 0x007a,
        GHOSTTY_KEY_F2: 0x0078,
        GHOSTTY_KEY_F3: 0x0063,
        GHOSTTY_KEY_F4: 0x0076,
        GHOSTTY_KEY_F5: 0x0060,
        GHOSTTY_KEY_F6: 0x0061,
        GHOSTTY_KEY_F7: 0x0062,
        GHOSTTY_KEY_F8: 0x0064,
        GHOSTTY_KEY_F9: 0x0065,
        GHOSTTY_KEY_F10: 0x006d,
        GHOSTTY_KEY_F11: 0x0067,
        GHOSTTY_KEY_F12: 0x006f,

        // Modifier keys
        GHOSTTY_KEY_SHIFT_LEFT: 0x0038,
        GHOSTTY_KEY_SHIFT_RIGHT: 0x003c,
        GHOSTTY_KEY_CONTROL_LEFT: 0x003b,
        GHOSTTY_KEY_CONTROL_RIGHT: 0x003e,
        GHOSTTY_KEY_ALT_LEFT: 0x003a,
        GHOSTTY_KEY_ALT_RIGHT: 0x003d,
        GHOSTTY_KEY_META_LEFT: 0x0037,
        GHOSTTY_KEY_META_RIGHT: 0x0036,

        // Numpad
        GHOSTTY_KEY_NUMPAD_0: 0x0052,
        GHOSTTY_KEY_NUMPAD_1: 0x0053,
        GHOSTTY_KEY_NUMPAD_2: 0x0054,
        GHOSTTY_KEY_NUMPAD_3: 0x0055,
        GHOSTTY_KEY_NUMPAD_4: 0x0056,
        GHOSTTY_KEY_NUMPAD_5: 0x0057,
        GHOSTTY_KEY_NUMPAD_6: 0x0058,
        GHOSTTY_KEY_NUMPAD_7: 0x0059,
        GHOSTTY_KEY_NUMPAD_8: 0x005b,
        GHOSTTY_KEY_NUMPAD_9: 0x005c,
        GHOSTTY_KEY_NUMPAD_ADD: 0x0045,
        GHOSTTY_KEY_NUMPAD_SUBTRACT: 0x004e,
        GHOSTTY_KEY_NUMPAD_MULTIPLY: 0x0043,
        GHOSTTY_KEY_NUMPAD_DIVIDE: 0x004b,
        GHOSTTY_KEY_NUMPAD_DECIMAL: 0x0041,
        GHOSTTY_KEY_NUMPAD_ENTER: 0x004c,
        GHOSTTY_KEY_NUMPAD_EQUAL: 0x0051,
        GHOSTTY_KEY_NUM_LOCK: 0x0047,
    ]
}
