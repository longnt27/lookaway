import AppKit
import SwiftUI
import XCTest
@testable import LookAway

@MainActor
final class SettingsLayoutTests: XCTestCase {
    func testAccessibilityDiagnostics() {
        let window = makeSettingsWindow()
        defer { window.close() }

        let elements = accessibilityElements(from: window.contentView)
        let summary = elements.prefix(120).map { element in
            let label = element.accessibilityLabel() ?? ""
            let title = element.accessibilityTitle() ?? ""
            let role = element.accessibilityRole()?.rawValue ?? ""
            let value = String(describing: element.accessibilityValue() ?? "")
            return "role=\(role) label=\(label) title=\(title) value=\(value)"
        }.joined(separator: "\n")
        XCTFail("Accessibility tree:\n\(summary)")
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

    private func accessibilityElements(from root: Any?) -> [NSAccessibilityProtocol] {
        guard let root else { return [] }
        var queue: [Any] = [root]
        var result: [NSAccessibilityProtocol] = []
        var seen = Set<ObjectIdentifier>()

        while !queue.isEmpty && result.count < 500 {
            let candidate = queue.removeFirst()
            guard let object = candidate as AnyObject?, let element = candidate as? NSAccessibilityProtocol else { continue }
            let id = ObjectIdentifier(object)
            guard seen.insert(id).inserted else { continue }
            result.append(element)
            queue.append(contentsOf: element.accessibilityChildren() ?? [])
        }
        return result
    }
}
