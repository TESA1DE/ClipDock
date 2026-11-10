import SwiftUI
#if SWIFT_PACKAGE
import ClipDockCore
#endif

struct ClipboardSettingsView: View {
    @ObservedObject var store: ClipboardStore
    var pasteService: PasteService
    @State private var trusted = false
    @State private var confirmClear = false
    var body: some View {
        Section("Insert into Active App") {
            Toggle("Automatically paste selected items", isOn: $store.settings.pasteOnSelection)
            Text("Click an item or press Return to insert it into the field active before opening ClipDock. The panel closes for insertion. Use Copy Only in the context menu to copy without pasting.").font(.caption).foregroundStyle(.secondary)
            if store.settings.pasteOnSelection {
                HStack {
                    Label(trusted ? "Accessibility access granted" : "Accessibility access required", systemImage: trusted ? "checkmark.shield" : "hand.raised")
                    Spacer()
                    if !trusted { Button("Enable Accessibility…") { pasteService.requestPermission() } }
                }
                Text("Drag text, images, or files directly into a compatible field or drop area. Dragging does not require Accessibility access.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .onAppear { trusted = pasteService.isTrusted }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in trusted = pasteService.isTrusted }
        Section("History") {
            Toggle("Enable clipboard history", isOn: $store.settings.historyEnabled)
            Picker("Maximum history", selection: $store.settings.historyLimit) {
                ForEach([50, 100, 250, 500, 0], id: \.self) { Text($0 == 0 ? "Unlimited" : "\($0) items").tag($0) }
            }
            Toggle("Close after copying", isOn: $store.settings.closeAfterCopy)
            Toggle("Save history between launches", isOn: $store.settings.saveHistory)
            Text("Pinned items are always saved and never expire. The history limit applies to unpinned items.").font(.caption).foregroundStyle(.secondary)
        }
        Section("Automatic Cleanup") {
            Picker("Remove unpinned items after", selection: $store.settings.retentionSeconds) {
                Text("Never").tag(0.0)
                Text("5 minutes").tag(300.0)
                Text("15 minutes").tag(900.0)
                Text("1 hour").tag(3600.0)
                Text("24 hours").tag(86400.0)
                Text("7 days").tag(604800.0)
                Text("30 days").tag(2592000.0)
            }
            Text("Expired history is removed within about 30 seconds, on opening the panel, and on launch. Pinned items are kept. Choosing a shorter interval applies immediately.").font(.caption).foregroundStyle(.secondary)
            Toggle("Also clear the current system clipboard", isOn: $store.settings.clearSystemClipboard)
                .disabled(store.settings.retentionSeconds == 0)
            Text("Uses the same interval, only for content captured or copied by ClipDock. A newer clipboard value is never cleared by an older timer.").font(.caption).foregroundStyle(.secondary)
        }
        Section("Storage") {
            Text("Images are resized to at most 2,048 pixels. Unpinned images share a 200 MB budget, including with Unlimited history. Pinned images remain until you delete them.").font(.callout).foregroundStyle(.secondary)
            HStack {
                Button("Clear History") { store.clear() }
                Spacer()
                Button("Clear Everything…", role: .destructive) { confirmClear = true }
            }
        }
        .alert("Clear everything?", isPresented: $confirmClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear Everything", role: .destructive) { store.clear(includePinned: true) }
        } message: { Text("All clipboard items, including pinned items, will be deleted. This cannot be undone. Your current system clipboard will not change.") }
    }
}
