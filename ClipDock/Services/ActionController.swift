import AppKit
import SwiftUI
#if SWIFT_PACKAGE
import ClipDockCore
#endif

@MainActor
final class ActionController: ObservableObject {
    @Published private(set) var library = ActionLibrary()
    @Published var message = ""
    @Published private(set) var running: UUID?
    @Published private(set) var enabled: Set<UUID> = [] { didSet { UserDefaults.standard.set(!enabled.isEmpty || gameActive, forKey: "actionsNeedRecovery") } }
    @Published private(set) var gameActive = false { didSet { UserDefaults.standard.set(!enabled.isEmpty || gameActive, forKey: "actionsNeedRecovery") } }
    private var launchedMouse: NSRunningApplication?
    private var keys: [GlobalHotKeyManager] = []
    private var process: Process?
    private var writable = true
    private let file: URL
    init(directory: URL? = nil) {
        file = (directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("com.clipdock.app")).appendingPathComponent("actions.json")
        do { library = try ActionLibrary.load(from: file)
            if directory == nil, UserDefaults.standard.bool(forKey: "actionsNeedRecovery") { message = "Previous session ended with active actions. Restore keyboard settings and any script effects manually; state is unknown. Nothing was executed on restart." }
        }
        catch { writable = false; message = "Cannot read actions.json. Original file preserved: \(error.localizedDescription)" }
    }
    func save(_ value: UserAction) {
        guard running == nil, !enabled.contains(value.id) else { message = "Turn the action OFF before editing it."; return }
        var next = library
        if let i = next.actions.firstIndex(where: { $0.id == value.id }) { next.actions[i] = value } else { next.actions.append(value) }
        commit(next)
    }
    func remove(_ action: UserAction) {
        guard running == nil, !enabled.contains(action.id) else { message = "Turn the action OFF before deleting it."; return }
        var next = library; next.actions.removeAll { $0.id == action.id }; commit(next)
    }
    func setGameShortcut(_ key: HotKey?) { var next = library; next.gameShortcut = key; commit(next) }
    private func commit(_ next: ActionLibrary) {
        guard writable else { return }
        do { try next.save(to: file); library = next; message = "Saved"; registerShortcuts() }
        catch { message = "Could not save: \(error.localizedDescription)" }
    }
    func registerShortcuts() {
        keys.forEach { $0.stop() }; keys.removeAll()
        for action in library.actions {
            if let shortcut = action.shortcut { addKey(shortcut, name: action.name) { [weak self] in self?.run(action) } }
        }
        if let shortcut = library.gameShortcut { addKey(shortcut, name: "Game Mode") { [weak self] in self?.toggleGameMode() } }
    }
    private func addKey(_ shortcut: HotKey, name: String, callback: @escaping () -> Void) {
        let key = GlobalHotKeyManager(); key.onTrigger = callback
        if key.register(shortcut) { keys.append(key) }
        else { key.stop(); message = "Shortcut unavailable for \(name). Choose another combination." }
    }
    func run(_ action: UserAction) {
        guard running == nil else { message = "Wait for the current action to finish."; return }
        if action.kind == .script || action.kind == .toggle {
            let turningOff = enabled.contains(action.id)
            let url = URL(fileURLWithPath: turningOff ? action.offPath : action.path)
            do {
                let source = try Self.readScript(url)
                let alert = NSAlert(); alert.messageText = "Run \(action.name)?"
                alert.informativeText = "This local script runs with your account's permissions and can change files. Only run code you trust.\n\(url.path)\n\n" + "Review the complete script below."
                let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 520, height: 220))
                let text = NSTextView(frame: scroll.bounds); text.string = source; text.isEditable = false
                text.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
                text.isVerticallyResizable = true; text.autoresizingMask = [.width]
                scroll.documentView = text; scroll.hasVerticalScroller = true
                alert.accessoryView = scroll
                alert.addButton(withTitle: "Run script"); alert.addButton(withTitle: "Cancel")
                NSApp.activate(ignoringOtherApps: true)
                guard alert.runModal() == .alertFirstButtonReturn else { return }
                // Execute precisely the bytes shown/approved, not a file that could change after approval.
                running = action.id; message = "Running \(action.name)…"
                let task = Self.makeScriptProcess(source: source, url: url); process = task
                task.terminationHandler = { [weak self] process in
                    Task { @MainActor in
                        guard let self else { return }
                        self.running = nil; self.process = nil
                        self.message = "\(action.name): exit \(process.terminationStatus)"
                        if process.terminationStatus == 0, action.kind == .toggle {
                            if turningOff { self.enabled.remove(action.id) } else { self.enabled.insert(action.id) }
                        }
                    }
                }
                try task.run()
            } catch { running = nil; process = nil; message = error.localizedDescription }
            return
        }
        let url = URL(fileURLWithPath: action.path)
        guard url.pathExtension == "app", let bundleID = Bundle(url: url)?.bundleIdentifier, bundleID != Bundle.main.bundleIdentifier else { message = "Choose an existing application other than ClipDock."; return }
        running = action.id
        Task {
            defer { running = nil }
            do {
                if action.kind == .launch {
                    _ = try await NSWorkspace.shared.openApplication(at: url, configuration: .init())
                    message = "Opened \(action.name)"
                } else {
                    let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                    guard apps.allSatisfy({ $0.terminate() }) else { throw CocoaError(.userCancelled) }
                    for _ in 0..<50 where apps.contains(where: { !$0.isTerminated }) { try await Task.sleep(for: .milliseconds(100)) }
                    message = apps.allSatisfy(\.isTerminated) ? "Closed \(action.name)" : "App is still running; check unsaved documents."
                }
            } catch { message = error.localizedDescription }
        }
    }
    nonisolated static func readScript(_ url: URL) throws -> String {
        let fresh = URL(fileURLWithPath: url.path)
        guard ["sh", "command"].contains(url.pathExtension.lowercased()), url.isFileURL,
              try fresh.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { throw CocoaError(.fileReadUnsupportedScheme) }
        let handle = try FileHandle(forReadingFrom: fresh)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 128 * 1024 + 1) ?? Data()
        guard data.count <= 128 * 1024, let source = String(data: data, encoding: .utf8), !source.contains("\0") else { throw CocoaError(.fileReadCorruptFile) }
        return source
    }
    nonisolated static func makeScriptProcess(source: String, url: URL) -> Process {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["--noprofile", "--norc", "-c", source, url.path]
        task.currentDirectoryURL = url.deletingLastPathComponent()
        task.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HOME": NSHomeDirectory(), "LANG": "en_US.UTF-8"]
        task.standardInput = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice; task.standardError = FileHandle.nullDevice
        return task
    }
    func stop() { process?.terminate(); message = "Stop requested. Child processes created by a script may need to be stopped separately." }
    func toggleGameMode() {
        guard running == nil else { return }
        let alert = NSAlert()
        alert.messageText = gameActive ? "Turn Game Mode OFF?" : "Game Mode — manual keyboard step"
        alert.informativeText = gameActive
            ? "Restore the original Function Keys setting yourself in System Settings. ClipDock will close only the LinearMouse process it launched."
            : "On macOS \(ProcessInfo.processInfo.operatingSystemVersionString), automatic F1–F12 switching is not verified. Note your original setting, then enable standard function keys in Keyboard → Keyboard Shortcuts → Function Keys. Confirm only after changing it. ClipDock never writes fnState."
        alert.addButton(withTitle: gameActive ? "I restored it — turn OFF" : "I changed it — turn ON")
        alert.addButton(withTitle: "Open Keyboard Settings")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        let result = alert.runModal()
        if result == .alertSecondButtonReturn { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!); return }
        guard result == .alertFirstButtonReturn else { return }
        if gameActive {
            running = UUID()
            Task {
                defer { running = nil }
                if let app = launchedMouse, !app.isTerminated {
                    guard app.terminate() else { message = "LinearMouse refused to quit. Retry OFF."; return }
                    for _ in 0..<50 where !app.isTerminated { try? await Task.sleep(for: .milliseconds(100)) }
                    guard app.isTerminated else { message = "LinearMouse is still running. Close it, then retry OFF."; return }
                }
                launchedMouse = nil; gameActive = false; message = "Game Mode OFF (keyboard restoration confirmed by you)."
            }
        } else {
            let id = "com.lujjjh.LinearMouse"
            if !NSRunningApplication.runningApplications(withBundleIdentifier: id).isEmpty { gameActive = true; message = "Game Mode ON; existing LinearMouse will be left running."; return }
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { message = "LinearMouse is not installed. Game Mode not enabled; restore your keyboard setting if you changed it."; return }
            running = UUID()
            Task {
                defer { running = nil }
                do { launchedMouse = try await NSWorkspace.shared.openApplication(at: url, configuration: .init()); gameActive = true; message = "Game Mode ON — keyboard state is manually confirmed." }
                catch { message = "LinearMouse failed: \(error.localizedDescription). Restore your keyboard setting manually." }
            }
        }
    }
    func shutdown() { keys.forEach { $0.stop() }; process?.terminate() }
}
