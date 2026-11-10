import SwiftUI
import Carbon
#if SWIFT_PACKAGE
import ClipDockCore
#endif

struct ActionsSettingsView: View {
    @ObservedObject var controller: ActionController
    @State private var draft: UserAction?
    var body: some View {
        Section("Game Mode · assisted") {
            Text(controller.gameActive ? "ON — keyboard confirmed manually" : "OFF")
            Text("F1–F12 requires a manual change in Keyboard settings. LinearMouse is managed automatically. Turn OFF before quitting ClipDock.").font(.caption)
            ShortcutPicker(value: Binding(get: { controller.library.gameShortcut }, set: { controller.setGameShortcut($0) }))
            Button(controller.gameActive ? "Turn OFF…" : "Turn ON…") { controller.toggleGameMode() }.disabled(controller.running != nil)
        }
        Section("Your actions") {
            ForEach(controller.library.actions) { action in
                VStack(alignment: .leading) {
                    HStack {
                        Text(action.name).bold()
                        Spacer()
                        if action.kind == .toggle { Text(controller.enabled.contains(action.id) ? "ON" : "OFF") }
                        Button("Run") { controller.run(action) }.disabled(controller.running != nil)
                        Button("Edit") { draft = action }.disabled(controller.running != nil || controller.enabled.contains(action.id))
                        Button("Delete", role: .destructive) { controller.remove(action) }.disabled(controller.running != nil || controller.enabled.contains(action.id))
                    }
                    Text(action.detail).font(.caption)
                    Text(action.shortcut?.label ?? "No global shortcut").font(.caption).foregroundStyle(.secondary)
                }
            }
            Button("Add action…") { draft = UserAction() }.disabled(controller.running != nil)
        }
        Section("Last result") {
            Text(controller.message.isEmpty ? "Ready" : controller.message).textSelection(.enabled)
            if controller.running != nil { Button("Stop script") { controller.stop() } }
            Text("Scripts require confirmation every time and run as your user, not in a sandbox. ON/OFF state lasts for this session; turn actions OFF before quitting. No scripts run on startup.").font(.caption).foregroundStyle(.secondary)
        }
        .sheet(item: $draft) { action in ActionEditor(action: action) { controller.save($0); draft = nil } }
    }
}

private struct ActionEditor: View {
    @State var action: UserAction
    var save: (UserAction) -> Void
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Edit action").font(.title2)
            TextField("Name", text: $action.name)
            TextField("Description", text: $action.detail)
            Picker("Type", selection: $action.kind) { ForEach(ActionKind.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            Button("Choose \(action.kind == .launch || action.kind == .quit ? "application" : "ON script")…") { choose(off: false) }
            Text(action.path.isEmpty ? "No file selected" : action.path).font(.caption).lineLimit(2)
            if action.kind == .toggle {
                Button("Choose OFF script…") { choose(off: true) }
                Text(action.offPath.isEmpty ? "No OFF script selected" : action.offPath).font(.caption).lineLimit(2)
            }
            ShortcutPicker(value: $action.shortcut)
            HStack { Button("Cancel") { dismiss() }; Spacer(); Button("Save") { save(action) }.disabled(action.name.trimmingCharacters(in: .whitespaces).isEmpty || action.path.isEmpty || (action.kind == .toggle && action.offPath.isEmpty)) }
        }.padding(24).frame(width: 500)
    }
    private func choose(off: Bool) {
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.message = action.kind == .launch || action.kind == .quit ? "Choose an .app bundle" : "Choose a trusted UTF-8 .sh or .command script (Bash)"
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            if off { action.offPath = url.path } else { action.path = url.path }
        }
    }
}

struct ShortcutPicker: View {
    @Binding var value: HotKey?
    @State private var monitor: Any?
    var body: some View {
        HStack {
            Button(monitor == nil ? (value?.label ?? "Assign shortcut…") : "Press shortcut (Esc cancels)") { record() }
            Button("Clear") { end(); value = nil }
        }.onDisappear { end() }
    }
    private func end() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }
    private func record() {
        end()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { end(); return nil }
            let flags = event.modifierFlags
            guard !flags.intersection([.command, .option, .control]).isEmpty else { return nil }
            var modifiers: UInt32 = 0; var label = ""
            for (flag, carbon, symbol): (NSEvent.ModifierFlags, Int, String) in [(.control, controlKey, "⌃"), (.option, optionKey, "⌥"), (.shift, shiftKey, "⇧"), (.command, cmdKey, "⌘")] {
                if flags.contains(flag) { modifiers |= UInt32(carbon); label += symbol }
            }
            label += event.keyCode == 49 ? " Space" : " " + (event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)")
            value = HotKey(keyCode: UInt32(event.keyCode), modifiers: modifiers, label: label); end(); return nil
        }
    }
}
