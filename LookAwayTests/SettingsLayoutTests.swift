import AppKit
import SwiftUI
import XCTest
@testable import LookAway

@MainActor
final class SettingsLayoutTests: XCTestCase {
    func testBreakEveryLabelStaysOnOneLineAtMinimumWindowWidth() throws {
        let window = makeSettingsWindow()
        defer { window.close() }

        let breakTab = try XCTUnwrap(findAccessibilityElement(label: "Breaks", in: window.contentView))
        XCTAssertTrue(breakTab.accessibilityPerformPress())
        settleLayout(window)

        let label = try XCTUnwrap(findAccessibilityElement(label: "Break every", in: window.contentView))
        let frame = label.accessibilityFrame()
        XCTAssertGreaterThanOrEqual(frame.width, 90, "The setting label must not be squeezed into a narrow wrapping column")
        XCTAssertLessThanOrEqual(frame.height, 24, "The setting label must remain a single line")
    }

    func testSettingsDoNotShowExplanatoryHelperParagraphs() {
        let window = makeSettingsWindow()
        defer { window.close() }

        settleLayout(window)
        XCTAssertNil(findAccessibilityElement(
            label: "Managed by macOS. Changes to launch at login apply immediately, independently of Save or Cancel. Install LookAway in Applications first.",
            in: window.contentView
        ))
        XCTAssertNil(findAccessibilityElement(
            label: "Saving timing changes starts a fresh work session. Paused timers stay paused; active breaks finish normally. Other preferences do not reset the timer.",
            in: window.contentView
        ))
    }

    private func makeSettingsWindow() -> NSWindow {
        let editor = SettingsEditor(settings: .defaults) { _ in }
        let login = LoginItemController(
            readStatus: { .disabled },
            register: {},
            unregister: {},
            openSystemSettings: {}
        )
        let view = SettingsView(
            editor: editor,
            login: login,
            soundPlayer: SoundPlayer(),
            onPreview: { _ in },
            onClose: {}
        )
        let host = NSHostingController(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 620),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = host
        window.makeKeyAndOrderFront(nil)
        settleLayout(window)
        return window
    }

    private func settleLayout(_ window: NSWindow) {
        window.contentView?.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        window.contentView?.layoutSubtreeIfNeeded()
    }

    private func findAccessibilityElement(label: String, in root: Any?) -> NSAccessibilityProtocol? {
        guard let element = root as? NSAccessibilityProtocol else { return nil }
        if element.accessibilityLabel() == label { return element }
        for child in element.accessibilityChildren() ?? [] {
            if let match = findAccessibilityElement(label: label, in: child) { return match }
        }
        return nil
    }
}
