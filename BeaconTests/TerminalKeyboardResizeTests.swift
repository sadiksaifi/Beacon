import Foundation
import Testing
@testable import Beacon

/// Tests for the keyboard resize calculation used by `TerminalSurface.Coordinator`.
///
/// The coordinator computes available terminal size by subtracting the
/// keyboard overlap from the terminal view bounds. Since the actual
/// `handleKeyboardChange` method is private and requires a live UIView
/// hierarchy (window, screen coordinate space), these tests verify the
/// underlying CGRect math and the minimum-height floor independently.
@Suite("Terminal Keyboard Resize Calculation")
struct TerminalKeyboardResizeTests {

    /// Reproduces the calculation from `TerminalSurface.Coordinator.handleKeyboardChange`:
    /// ```
    /// let overlap = viewBounds.intersection(keyboardFrameInView)
    /// let availableHeight = viewBounds.height - (overlap.isNull ? 0 : overlap.height)
    /// let availableSize = CGSize(width: viewBounds.width, height: max(availableHeight, 100))
    /// ```
    private func calculateAvailableSize(
        viewBounds: CGRect,
        keyboardFrameInView: CGRect
    ) -> CGSize {
        let overlap = viewBounds.intersection(keyboardFrameInView)
        let availableHeight = viewBounds.height
            - (overlap.isNull ? 0 : overlap.height)
        return CGSize(
            width: viewBounds.width,
            height: max(availableHeight, 100)
        )
    }

    // MARK: - Standard Keyboard Overlap

    @Test("Keyboard covering bottom 300pt of 800pt view leaves 500pt height")
    func standardKeyboardOverlap() {
        let viewBounds = CGRect(x: 0, y: 0, width: 400, height: 800)
        // Keyboard frame starts at y=500 within the view, 300pt tall
        let keyboardFrame = CGRect(x: 0, y: 500, width: 400, height: 300)

        let size = calculateAvailableSize(
            viewBounds: viewBounds,
            keyboardFrameInView: keyboardFrame
        )

        #expect(size.width == 400)
        #expect(size.height == 500)
    }

    // MARK: - No Keyboard (Hidden or Offscreen)

    @Test("Keyboard fully offscreen results in full view height")
    func keyboardOffscreen() {
        let viewBounds = CGRect(x: 0, y: 0, width: 400, height: 800)
        // Keyboard is below the view — no intersection
        let keyboardFrame = CGRect(x: 0, y: 900, width: 400, height: 300)

        let size = calculateAvailableSize(
            viewBounds: viewBounds,
            keyboardFrameInView: keyboardFrame
        )

        #expect(size.width == 400)
        #expect(size.height == 800)
    }

    // MARK: - Floating Keyboard (No Overlap)

    @Test("Floating keyboard that does not overlap view preserves full height")
    func floatingKeyboardNoOverlap() {
        let viewBounds = CGRect(x: 0, y: 0, width: 400, height: 800)
        // Floating keyboard offset to the right, no horizontal overlap
        let keyboardFrame = CGRect(x: 500, y: 400, width: 300, height: 200)

        let size = calculateAvailableSize(
            viewBounds: viewBounds,
            keyboardFrameInView: keyboardFrame
        )

        #expect(size.width == 400)
        #expect(size.height == 800)
    }

    // MARK: - Minimum Height Floor

    @Test("Keyboard covering almost entire view clamps to 100pt minimum")
    func minimumHeightFloor() {
        let viewBounds = CGRect(x: 0, y: 0, width: 400, height: 800)
        // Keyboard covers 750pt of 800pt view, leaving only 50pt
        let keyboardFrame = CGRect(x: 0, y: 50, width: 400, height: 750)

        let size = calculateAvailableSize(
            viewBounds: viewBounds,
            keyboardFrameInView: keyboardFrame
        )

        #expect(size.width == 400)
        // 800 - 750 = 50, but minimum is 100
        #expect(size.height == 100)
    }

    @Test("Keyboard fully covering view clamps to 100pt minimum")
    func keyboardFullyCoveringView() {
        let viewBounds = CGRect(x: 0, y: 0, width: 400, height: 800)
        // Keyboard is larger than the view
        let keyboardFrame = CGRect(x: 0, y: 0, width: 400, height: 900)

        let size = calculateAvailableSize(
            viewBounds: viewBounds,
            keyboardFrameInView: keyboardFrame
        )

        #expect(size.width == 400)
        // 800 - 800 (clamped overlap) = 0, minimum is 100
        #expect(size.height == 100)
    }

    // MARK: - Partial Width Overlap

    @Test("Keyboard partially overlapping horizontally still subtracts vertical overlap")
    func partialWidthOverlap() {
        let viewBounds = CGRect(x: 0, y: 0, width: 400, height: 800)
        // Keyboard only covers half the width, but full bottom 300pt
        let keyboardFrame = CGRect(x: 0, y: 500, width: 200, height: 300)

        let size = calculateAvailableSize(
            viewBounds: viewBounds,
            keyboardFrameInView: keyboardFrame
        )

        #expect(size.width == 400)
        // CGRect.intersection with partial width still reports 300pt height overlap
        #expect(size.height == 500)
    }

    // MARK: - Zero-Height Keyboard

    @Test("Zero-height keyboard frame results in full view height")
    func zeroHeightKeyboard() {
        let viewBounds = CGRect(x: 0, y: 0, width: 400, height: 800)
        let keyboardFrame = CGRect(x: 0, y: 800, width: 400, height: 0)

        let size = calculateAvailableSize(
            viewBounds: viewBounds,
            keyboardFrameInView: keyboardFrame
        )

        #expect(size.width == 400)
        #expect(size.height == 800)
    }

    // MARK: - Exactly 100pt Remaining

    @Test("Keyboard leaving exactly 100pt does not trigger minimum clamp")
    func exactly100ptRemaining() {
        let viewBounds = CGRect(x: 0, y: 0, width: 400, height: 800)
        // 800 - 700 = 100, which equals the minimum
        let keyboardFrame = CGRect(x: 0, y: 100, width: 400, height: 700)

        let size = calculateAvailableSize(
            viewBounds: viewBounds,
            keyboardFrameInView: keyboardFrame
        )

        #expect(size.width == 400)
        #expect(size.height == 100)
    }

    // MARK: - Width Preservation

    @Test("Width is always preserved regardless of keyboard overlap")
    func widthAlwaysPreserved() {
        let viewBounds = CGRect(x: 0, y: 0, width: 1024, height: 768)
        let keyboardFrame = CGRect(x: 0, y: 400, width: 1024, height: 368)

        let size = calculateAvailableSize(
            viewBounds: viewBounds,
            keyboardFrameInView: keyboardFrame
        )

        #expect(size.width == 1024)
        #expect(size.height == 400)
    }
}
