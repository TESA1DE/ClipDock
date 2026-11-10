import SwiftUI
import Carbon
#if SWIFT_PACKAGE
import ClipDockCore
#endif

struct ShortcutSettingsView: View {
    @ObservedObject var store: ClipboardStore
    @State private var recording = false
    @State private var eventMonitor: Any?
    @State private var hint: String?
    var body: some View {
        Section("Global Shortcut") {
            HStack {
                Text("Open ClipDock")
                Spacer()
                Button(recording ? "Press shortcut…" : store.settings.hotKey.label) { startRecording() }
                    .font(.system(.body, design: .monospaced)).frame(minWidth: 130)
            }
            Text(hint ?? "Click the shortcut, then press a key with Command, Option, or Control. Escape cancels.").font(.caption).foregroundStyle(.secondary)
            Button("Restore Option + Space") { stopRecording(); if store.settings.hotKey != HotKey() { store.settings.hotKey = HotKey() } }
        }
        Section("In the Panel") {
            shortcut("Navigate clipboard", "↑ / ↓")
            shortcut("Copy selected item", "Return")
            shortcut("Pin or unpin", "⌘ P")
            shortcut("Delete selected item", "⌘ Delete")
            shortcut("Focus search", "⌘ F")
            shortcut("Clipboard / Apps", "⌘ 1 / ⌘ 2")
            shortcut("Move between controls", "Tab")
            shortcut("Close panel", "Escape")
        }
        .onDisappear { stopRecording() }
    }
    private func shortcut(_ title: String, _ keys: String) -> some View {
        HStack { Text(title); Spacer(); Text(keys).foregroundStyle(.secondary).font(.system(.body, design: .monospaced)) }
    }
    private func startRecording() {
        stopRecording(); recording = true; hint = nil
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { stopRecording(); return nil }
            let flags = event.modifierFlags
            guard !flags.intersection([.command, .option, .control]).isEmpty else { hint = "Include Command, Option, or Control."; return nil }
            var modifiers: UInt32 = 0
            var label = ""
            if flags.contains(.control) { modifiers |= UInt32(controlKey); label += "⌃" }
            if flags.contains(.option) { modifiers |= UInt32(optionKey); label += "⌥" }
            if flags.contains(.shift) { modifiers |= UInt32(shiftKey); label += "⇧" }
            if flags.contains(.command) { modifiers |= UInt32(cmdKey); label += "⌘" }
            let keyNames: [UInt16: String] = [49: "Space", 36: "Return", 48: "Tab", 51: "Delete", 123: "←", 124: "→", 125: "↓", 126: "↑"]
            label += " " + (keyNames[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)")
            let hotKey = HotKey(keyCode: UInt32(event.keyCode), modifiers: modifiers, label: label)
            stopRecording()
            if hotKey != store.settings.hotKey { store.settings.hotKey = hotKey }
            return nil
        }
    }
    private func stopRecording() { if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }; eventMonitor = nil; recording = false }
}
