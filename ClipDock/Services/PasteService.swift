import AppKit
import ApplicationServices

@MainActor
final class PasteService {
    private var target: NSRunningApplication?
    private var focusedElement: AXUIElement?
    private var generation = 0
    var hasTarget: Bool { target != nil }
    var isTrusted: Bool { AXIsProcessTrusted() }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    func captureTarget() {
        generation += 1
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            target = nil; focusedElement = nil; return
        }
        target = app
        focusedElement = isTrusted ? focusedControl(in: app) : nil
    }
    func validationMessage() -> String? {
        guard let target, !target.isTerminated else { return "Copied. The destination app is no longer available." }
        guard isTrusted else { return "Copied. Enable Accessibility for ClipDock in Settings → Clipboard to insert into the active app. You can still paste manually with ⌘V." }
        guard let focusedElement, isEditable(focusedElement) else { return "Copied. No editable field was detected in the destination app. Focus a field and use ⌘V." }
        return nil
    }
    func paste(changeCount: Int) async -> String? {
        guard let target, let expectedFocus = focusedElement else { return "Copied. Focus a destination field and use ⌘V." }
        let token = generation
        guard target.activate(options: []) else { return "Copied. The destination app could not be activated." }
        let deadline = Date().addingTimeInterval(0.6)
        while Date() < deadline {
            guard token == generation, !Task.isCancelled else { return "Paste cancelled." }
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier,
               let focus = focusedControl(in: target), CFEqual(focus, expectedFocus) { break }
            try? await Task.sleep(for: .milliseconds(20))
        }
        guard token == generation, !target.isTerminated,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier,
              NSPasteboard.general.changeCount == changeCount,
              let focus = focusedControl(in: target), CFEqual(focus, expectedFocus), isEditable(focus) else {
            return "Copied. The destination focus or clipboard changed; use ⌘V in the intended field."
        }
        guard isTrusted,
              let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else { return "Copied. Automatic paste is unavailable; use ⌘V." }
        down.flags = .maskCommand; up.flags = .maskCommand
        down.postToPid(target.processIdentifier); up.postToPid(target.processIdentifier)
        return nil
    }
    private func focusedControl(in app: NSRunningApplication) -> AXUIElement? {
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.2)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
    private func isEditable(_ element: AXUIElement) -> Bool {
        AXUIElementSetMessagingTimeout(element, 0.2)
        var enabled: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &enabled) == .success,
           let enabled = enabled as? Bool, !enabled { return false }
        var role: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success else { return false }
        if [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role as? String ?? "") { return true }
        var settable: DarwinBoolean = false
        return AXUIElementIsAttributeSettable(element, kAXSelectedTextRangeAttribute as CFString, &settable) == .success && settable.boolValue
    }
}
