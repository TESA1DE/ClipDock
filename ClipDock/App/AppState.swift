import AppKit
import SwiftUI
#if SWIFT_PACKAGE
import ClipDockCore
#endif

@MainActor
final class AppState: ObservableObject {
    enum Tab: String, CaseIterable { case clipboard = "Clipboard", apps = "Apps" }
    let store: ClipboardStore
    let monitor: ClipboardMonitor
    let launcher: ApplicationLauncher
    let pasteService = PasteService()
    var isDragging = false
    let hotKey = GlobalHotKeyManager()
    let actions = ActionController()
    private let active = ActiveApplicationMonitor()
    @Published var tab = Tab.clipboard
    @Published var settingsSection = "General"
    @Published var query = ""
    @Published var selectedID: UUID?
    @Published var focusRequest = UUID()
    @Published var toast: String?
    var closePanel: (() -> Void)?
    var openSettings: (() -> Void)?
    var showPanel: (() -> Void)?
    private var toastTask: Task<Void, Never>?
    init() {
        store = ClipboardStore()
        monitor = ClipboardMonitor(store: store, active: active)
        launcher = ApplicationLauncher(store: store)
        store.onClear = { [weak self] in self?.monitor.invalidatePendingCapture() }
    }
    var results: [ClipboardItem] { store.history.search(query) }
    var enabledApps: [QuickApp] { store.apps.filter(\.isEnabled) }
    func copy(_ item: ClipboardItem, allowPaste: Bool = true) {
        if allowPaste, store.settings.pasteOnSelection, pasteService.hasTarget {
            guard monitor.copy(item) else { return }
            if let message = pasteService.validationMessage() { store.errorMessage = message; return }
            let count = NSPasteboard.general.changeCount
            closePanel?()
            Task { @MainActor in
                if let message = await pasteService.paste(changeCount: count) { store.errorMessage = message }
            }
            return
        }
        if monitor.copy(item) {
            if store.settings.closeAfterCopy { closePanel?() }
            else {
                toast = "Copied to clipboard"
                toastTask?.cancel()
                toastTask = Task { try? await Task.sleep(for: .seconds(1.5)); if !Task.isCancelled { toast = nil } }
            }
        }
    }
    func launch(_ app: QuickApp) {
        launcher.launch(app) { [weak self] in
            guard let self else { return }
            if self.store.settings.closeAfterAction { self.closePanel?() }
        }
    }
    func selectValidItem() { if !results.contains(where: { $0.id == selectedID }) { selectedID = results.first?.id } }
    func handleKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let command = flags.contains(.command)
        if event.keyCode == 53 { closePanel?(); return true }
        if command, event.charactersIgnoringModifiers == "1" { tab = .clipboard; focusRequest = UUID(); return true }
        if command, event.charactersIgnoringModifiers == "2" { tab = .apps; return true }
        if command, event.charactersIgnoringModifiers == "f" { tab = .clipboard; focusRequest = UUID(); return true }
        if tab == .apps {
            if store.settings.numberShortcuts, flags.isDisjoint(with: [.command, .option, .control]),
               let value = Int(event.characters ?? ""), value >= 1, value <= min(9, enabledApps.count) {
                launch(enabledApps[value - 1]); return true
            }
            return false
        }
        if [125, 126].contains(event.keyCode), flags.isDisjoint(with: [.command, .option, .control, .shift]) {
            let items = results
            guard !items.isEmpty else { return true }
            let current = items.firstIndex(where: { $0.id == selectedID }) ?? 0
            selectedID = items[max(0, min(items.count - 1, current + (event.keyCode == 125 ? 1 : -1)))].id
            return true
        }
        guard let item = results.first(where: { $0.id == selectedID }) else { return false }
        if event.keyCode == 36, flags.isEmpty {
            if event.window?.firstResponder is NSTextView { copy(item); return true }
        }
        if command, event.charactersIgnoringModifiers == "p" { store.togglePin(item); return true }
        if command, event.keyCode == 51 { store.delete(item); selectValidItem(); return true }
        return false
    }
}
