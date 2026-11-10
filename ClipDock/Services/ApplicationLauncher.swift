import AppKit
#if SWIFT_PACKAGE
import ClipDockCore
#endif
import UniformTypeIdentifiers

@MainActor
final class ApplicationLauncher {
    private let store: ClipboardStore
    private var icons: [String: NSImage] = [:]
    init(store: ClipboardStore) { self.store = store }
    func resolvedURL(_ app: QuickApp) -> URL? {
        let url = URL(fileURLWithPath: app.path)
        if FileManager.default.fileExists(atPath: url.path) { return url }
        return app.bundleIdentifier.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
    }
    func icon(_ app: QuickApp) -> NSImage {
        if let cached = icons[app.path] { return cached }
        let icon = NSWorkspace.shared.icon(forFile: resolvedURL(app)?.path ?? app.path)
        icons[app.path] = icon; return icon
    }
    func launch(_ app: QuickApp, completion: @escaping () -> Void) {
        guard let url = resolvedURL(app) else { store.errorMessage = "\(app.name) could not be found. Add it again in Settings → Apps."; return }
        if let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleURL == url }) {
            running.activate(options: [.activateAllWindows]); completion(); return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            Task { @MainActor in
                if error != nil { self?.store.errorMessage = "\(app.name) could not be opened. Check that it is still installed and accessible." }
                else { completion() }
            }
        }
    }
    func pickApplications(excluded: Bool = false) {
        let picker = NSOpenPanel()
        picker.title = excluded ? "Exclude Applications" : "Add Quick Apps"
        picker.prompt = excluded ? "Exclude" : "Add"
        picker.allowedContentTypes = [.applicationBundle]
        picker.canChooseDirectories = false; picker.allowsMultipleSelection = true
        picker.directoryURL = URL(fileURLWithPath: "/Applications")
        guard picker.runModal() == .OK else { return }
        for url in picker.urls {
            guard let bundle = Bundle(url: url) else { continue }
            if excluded {
                if let id = bundle.bundleIdentifier, !store.settings.excludedBundleIDs.contains(id) { store.settings.excludedBundleIDs.append(id) }
            } else if !store.apps.contains(where: { $0.path == url.path }) {
                let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? url.deletingPathExtension().lastPathComponent
                store.apps.append(QuickApp(name: name, path: url.path, bundleIdentifier: bundle.bundleIdentifier))
            }
        }
    }
    func reveal(_ app: QuickApp) {
        guard let url = resolvedURL(app) else { store.errorMessage = "This application is no longer available."; return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
