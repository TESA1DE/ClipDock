import AppKit
import SwiftUI
#if SWIFT_PACKAGE
import ClipDockCore
#endif

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let state = AppState()
    private var statusItem: NSStatusItem!
    private var panel: ClipDockPanel!
    private var settingsWindow: SettingsWindow?
    private var welcomeWindow: NSWindow?
    private var keyMonitor: Any?
    private var outsideMonitor: Any?
    private var correctingShortcut = false
    private var retentionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "square.on.square", accessibilityDescription: "ClipDock")
            button.image?.isTemplate = true; button.toolTip = "ClipDock"
            button.target = self; button.action = #selector(togglePanel)
        }
        panel = ClipDockPanel(contentRect: NSRect(x: 0, y: 0, width: 480, height: 570), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = NSHostingView(rootView: MainTabView(state: state, store: state.store))
        panel.delegate = self
        state.closePanel = { [weak self] in self?.panel.orderOut(nil) }
        state.openSettings = { [weak self] in self?.openSettings() }
        state.showPanel = { [weak self] in self?.presentPanel() }
        state.hotKey.onTrigger = { [weak self] in self?.togglePanel() }
        state.store.onSettingsChanged = { [weak self] old in self?.applySettings(previous: old) }
        applySettings(previous: nil)
        state.actions.registerShortcuts()
        state.monitor.start()
        retentionTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.state.store.expireHistory() }
        }
        retentionTimer?.tolerance = 5
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown, event.window === self.panel, self.state.handleKey(event) { return nil }
            if event.type != .keyDown, event.window !== self.panel, event.window !== self.statusItem.button?.window { self.panel.orderOut(nil) }
            return event
        }
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.panel.orderOut(nil)
        }
        if !state.store.settings.hasOnboarded { showWelcome() }
    }
    func applySettings(previous: AppSettings?) {
        let settings = state.store.settings
        if previous?.showDockIcon != settings.showDockIcon {
            NSApp.setActivationPolicy(settings.showDockIcon ? .regular : .accessory)
        }
        let appearance: NSAppearance?
        switch settings.appearance {
        case .light: appearance = NSAppearance(named: .aqua)
        case .dark: appearance = NSAppearance(named: .darkAqua)
        default: appearance = nil
        }
        NSApp.appearance = appearance
        let usesBackdrop = settings.appearance == .transparent || settings.appearance == .tinted
        settingsWindow?.isOpaque = !usesBackdrop
        settingsWindow?.backgroundColor = usesBackdrop ? .clear : .windowBackgroundColor
        if previous?.historyEnabled != settings.historyEnabled || previous?.excludedBundleIDs != settings.excludedBundleIDs { state.monitor.invalidatePendingCapture() }
        if !correctingShortcut, previous?.hotKey != settings.hotKey {
            if !state.hotKey.register(settings.hotKey) {
                state.store.errorMessage = "That shortcut is unavailable. Another app or macOS may already use it. Choose a different shortcut in Settings."
                if let previous {
                    correctingShortcut = true; state.store.settings.hotKey = previous.hotKey; correctingShortcut = false
                }
            }
        }
    }
    @objc func togglePanel() {
        if panel.isVisible { panel.orderOut(nil) } else { presentPanel() }
    }
    func presentPanel() {
        state.pasteService.captureTarget()
        state.store.expireHistory()
        state.query = ""; state.selectValidItem(); state.focusRequest = UUID()
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main!
        var frame = panel.frame
        switch state.store.settings.panelPosition {
        case .center:
            frame.origin = NSPoint(x: screen.visibleFrame.midX - frame.width / 2, y: screen.visibleFrame.midY - frame.height / 2)
        case .cursor:
            frame.origin = NSPoint(x: mouse.x - frame.width / 2, y: mouse.y - frame.height - 12)
        case .menuBar:
            let buttonFrame = statusItem.button.flatMap { $0.window?.convertToScreen($0.frame) }
            frame.origin = NSPoint(x: (buttonFrame?.midX ?? screen.visibleFrame.maxX) - frame.width / 2, y: (buttonFrame?.minY ?? screen.visibleFrame.maxY) - frame.height - 8)
        }
        let targetScreen = NSScreen.screens.first(where: { $0.frame.contains(NSPoint(x: frame.midX, y: frame.maxY)) }) ?? screen
        frame.origin.x = max(targetScreen.visibleFrame.minX + 8, min(frame.origin.x, targetScreen.visibleFrame.maxX - frame.width - 8))
        frame.origin.y = max(targetScreen.visibleFrame.minY + 8, min(frame.origin.y, targetScreen.visibleFrame.maxY - frame.height - 8))
        panel.setFrame(frame, display: false)
        panel.alphaValue = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 1 : 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in context.duration = 0.12; panel.animator().alphaValue = 1 }
        DispatchQueue.main.async { self.state.focusRequest = UUID() }
    }
    func openSettings() {
        panel.orderOut(nil)
        if settingsWindow == nil {
            let window = SettingsWindow(rootView: SettingsView(state: state, store: state.store))
            let usesBackdrop = state.store.settings.appearance == .transparent || state.store.settings.appearance == .tinted
            window.isOpaque = !usesBackdrop
            window.backgroundColor = usesBackdrop ? .clear : .windowBackgroundColor
            window.center(); settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true); settingsWindow?.makeKeyAndOrderFront(nil)
    }
    func showWelcome() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 340), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Welcome to ClipDock"; window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: WelcomeView(shortcut: state.store.settings.hotKey.label) { [weak self] settings in
            guard let self else { return }
            self.state.store.settings.hasOnboarded = true; self.welcomeWindow?.close()
            if settings { self.openSettings() } else { self.presentPanel() }
        })
        welcomeWindow = window; window.center(); NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil)
    }
    func windowDidResignKey(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === panel, !state.isDragging { panel.orderOut(nil) }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !panel.isVisible && !(settingsWindow?.isVisible ?? false) && !(welcomeWindow?.isVisible ?? false) { presentPanel() }
        return true
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.contains(where: { $0.scheme == "clipdock" && $0.host == "game-mode" && $0.query == nil && $0.path.isEmpty }) else { return }
        state.settingsSection = "Actions"; openSettings()
        state.actions.toggleGameMode()
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if state.actions.gameActive || !state.actions.enabled.isEmpty || state.actions.running != nil {
            state.actions.message = "Turn Game Mode and toggled actions OFF and stop running actions before quitting."
            state.settingsSection = "Actions"; openSettings(); return .terminateCancel
        }
        return .terminateNow
    }
    func applicationWillTerminate(_ notification: Notification) {
        retentionTimer?.invalidate()
        state.actions.shutdown()
        state.monitor.stop(); state.hotKey.stop(); state.store.prepareForTermination()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let outsideMonitor { NSEvent.removeMonitor(outsideMonitor) }
    }
}
