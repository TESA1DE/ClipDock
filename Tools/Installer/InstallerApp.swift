import AppKit

@main
struct ClipDockInstaller {
    @MainActor static func main() {
        let source = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("ClipDock.app", isDirectory: true)
        if CommandLine.arguments.contains("--self-test") {
            do { try InstallerEngine.selfTest(source: source); exit(0) }
            catch { fputs("Installer test failed: \(error.localizedDescription)\n", stderr); exit(1) }
        }
        let app = NSApplication.shared
        let delegate = InstallerDelegate(source: source)
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class InstallerDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let source: URL
    private var window: NSWindow!
    private let destination = NSPopUpButton()
    private let status = NSTextField(wrappingLabelWithString: "")
    private let installButton = NSButton(title: "Install", target: nil, action: nil)
    private let launchAfter = NSButton(checkboxWithTitle: "Launch ClipDock after installation", target: nil, action: nil)
    private let progress = NSProgressIndicator()
    private var busy = false
    private var installed: URL?
    init(source: URL) { self.source = source }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let appMenu = NSMenu()
        let root = NSMenuItem(); appMenu.addItem(root)
        root.submenu = NSMenu()
        root.submenu?.addItem(withTitle: "Quit Installer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = appMenu
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 440), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Install ClipDock"; window.delegate = self; window.isReleasedWhenClosed = false
        let icon = NSImageView()
        icon.image = NSWorkspace.shared.icon(forFile: source.path)
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 64).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 64).isActive = true
        let title = NSTextField(labelWithString: "ClipDock")
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        let subtitle = NSTextField(wrappingLabelWithString: "Your clipboard and apps, one shortcut away.")
        subtitle.textColor = .secondaryLabelColor
        destination.addItems(withTitles: ["For me — ~/Applications (no password)", "For all users — /Applications"])
        destination.target = self; destination.action = #selector(destinationChanged)
        launchAfter.state = .on
        installButton.target = self; installButton.action = #selector(installClicked); installButton.keyEquivalent = "\r"
        installButton.bezelStyle = .rounded
        progress.style = .spinning; progress.controlSize = .small; progress.isDisplayedWhenStopped = false
        let actions = NSStackView(views: [progress, installButton]); actions.orientation = .horizontal; actions.spacing = 12
        let note = NSTextField(wrappingLabelWithString: "macOS 14+ · Apple Silicon and Intel\nLocal build without Apple notarization. If macOS blocks launch, read the included installation instructions.")
        note.font = .systemFont(ofSize: 11); note.textColor = .secondaryLabelColor
        status.font = .systemFont(ofSize: 12)
        let stack = NSStackView(views: [icon, title, subtitle, destination, launchAfter, actions, status, note])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 15
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView(); content.addSubview(stack); window.contentView = content
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -24),
            destination.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        destinationChanged()
        window.center(); NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil)
    }
    private var directory: URL {
        destination.indexOfSelectedItem == 1 ? URL(fileURLWithPath: "/Applications", isDirectory: true) : FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
    }
    @objc private func destinationChanged() { status.stringValue = "Installation folder: \(directory.path)" }
    @objc private func installClicked() {
        if let installed { launch(installed); return }
        guard !busy else { return }
        let folder = directory
        let target = folder.appendingPathComponent("ClipDock.app")
        let exists = FileManager.default.fileExists(atPath: target.path)
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.clipdock.app")
        if exists || !running.isEmpty {
            let alert = NSAlert()
            alert.messageText = exists ? "Update ClipDock?" : "Close ClipDock to install?"
            alert.informativeText = "Running copies of ClipDock will be closed. History, pinned items and settings will be preserved."
            alert.addButton(withTitle: "Continue"); alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        busy = true; installButton.isEnabled = false; destination.isEnabled = false; launchAfter.isEnabled = false
        progress.startAnimation(nil); status.stringValue = "Installing…"
        Task { @MainActor in
            do {
                for app in running {
                    guard app.terminate() else { throw InstallError(message: "Close ClipDock manually and try again.") }
                }
                let deadline = Date().addingTimeInterval(10)
                while running.contains(where: { !$0.isTerminated }) && Date() < deadline { try? await Task.sleep(for: .milliseconds(100)) }
                guard running.allSatisfy(\.isTerminated) else { throw InstallError(message: "ClipDock is still running. Close it and try again.") }
                let source = self.source
                let result = try await Task.detached(priority: .userInitiated) {
                    try InstallerEngine.install(source: source, directory: folder, replaceExisting: exists)
                }.value
                installed = result
                status.stringValue = "Done. ClipDock is installed at \(result.path)"
                installButton.title = "Launch ClipDock"
                if launchAfter.state == .on { launch(result) }
            } catch {
                status.stringValue = "Could not install the application."
                let alert = NSAlert(); alert.messageText = "Installation incomplete"
                alert.informativeText = error.localizedDescription + "\nIf /Applications is not writable, choose installation for your user only."
                alert.runModal()
                destination.isEnabled = true; launchAfter.isEnabled = true
            }
            progress.stopAnimation(nil); busy = false; installButton.isEnabled = true
        }
    }
    private func launch(_ url: URL) {
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if error != nil {
                Task { @MainActor in
                    self.status.stringValue = "The app is installed. Open it in Finder; if macOS blocks launch, follow the included instructions."
                }
            }
        }
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { !busy }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { busy ? .terminateCancel : .terminateNow }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
