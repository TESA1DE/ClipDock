import AppKit
import Combine
#if SWIFT_PACKAGE
import ClipDockCore
#endif

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var history = History()
    @Published var apps: [QuickApp] = [] { didSet { persist() } }
    @Published var settings = AppSettings() { didSet { settingsChanged(oldValue) } }
    @Published var errorMessage: String?
    let storage: LocalStorage
    private let diskQueue = DispatchQueue(label: "com.clipdock.storage", qos: .utility)
    private var ready = false
    private var storageAvailable = true
    private var dragImageExpirations: [String: Date] = [:]
    var onClear: (() -> Void)?
    var onSettingsChanged: ((AppSettings) -> Void)?

    init(directory: URL? = nil) {
        let root = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("com.clipdock.app", isDirectory: true)
        storage = LocalStorage(directory: root)
        do {
            try storage.prepare()
            if let snapshot = try storage.load() {
                settings = snapshot.settings; apps = snapshot.apps
                history = History(items: snapshot.items.filter { settings.saveHistory || $0.isPinned })
                history.trim(limit: settings.historyLimit)
                history.expire(olderThan: settings.retentionSeconds)
            }
        } catch {
            storageAvailable = false
            errorMessage = "ClipDock could not read its local library. Your files have been left intact. Check access to Application Support/com.clipdock.app, then restart. Changes will remain in memory for this session."
        }
        ready = true
        persist()
    }
    private func settingsChanged(_ old: AppSettings) {
        guard ready else { return }
        history.trim(limit: settings.historyLimit)
        history.expire(olderThan: settings.retentionSeconds)
        onSettingsChanged?(old)
        persist()
    }
    func protectImageForDrag(_ item: ClipboardItem) {
        if let name = item.imageName { dragImageExpirations[name] = .distantFuture }
    }
    func finishDraggingImage(_ item: ClipboardItem, now: Date = Date()) {
        // Drop receivers may read the file shortly after AppKit finishes the drag session.
        if let name = item.imageName { dragImageExpirations[name] = now.addingTimeInterval(60) }
    }
    func expireHistory(now: Date = Date()) {
        let count = dragImageExpirations.count
        dragImageExpirations = dragImageExpirations.filter { $0.value > now }
        let expired = history.expire(olderThan: settings.retentionSeconds, now: now)
        if expired || count != dragImageExpirations.count { persist() }
    }
    func insert(_ item: ClipboardItem, imageData: Data? = nil) {
        history.expire(olderThan: settings.retentionSeconds)
        history.insert(item, limit: settings.historyLimit)
        persist(image: imageData.map { (item.imageName ?? "", $0) })
    }
    func togglePin(_ item: ClipboardItem) { history.togglePin(item.id); history.trim(limit: settings.historyLimit); persist() }
    func delete(_ item: ClipboardItem) { history.delete(item.id); persist() }
    func clear(includePinned: Bool = false) { onClear?(); history.clear(includePinned: includePinned); persist() }
    func imageURL(for item: ClipboardItem) -> URL? { item.imageName.flatMap(storage.imageURL) }
    func flush() { diskQueue.sync {} }
    private func persist(image: (String, Data)? = nil) {
        guard ready, storageAvailable else { return }
        let snapshot = Snapshot(items: history.items, apps: apps, settings: settings)
        let storage = storage
        // Keep session-only images until termination so disabling persistence does not break previews.
        let images = Set(history.items.compactMap(\.imageName)).union(dragImageExpirations.keys)
        diskQueue.async { [weak self] in
            do {
                if let (name, data) = image, let url = storage.imageURL(name) {
                    try data.write(to: url, options: .atomic)
                    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
                }
                try storage.save(snapshot)
                try storage.cleanImages(keeping: images)
            } catch {
                Task { @MainActor [weak self] in self?.errorMessage = "The local library could not be saved. Check available disk space and folder permissions. Changes may not survive a restart." }
            }
        }
    }
    func prepareForTermination() {
        flush()
        if storageAvailable {
            let names = Set(history.items.filter { settings.saveHistory || $0.isPinned }.compactMap(\.imageName))
            try? storage.cleanImages(keeping: names)
        }
    }
}
