import Foundation

public struct QuickApp: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var path: String
    public var bundleIdentifier: String?
    public var isEnabled: Bool
    public init(name: String, path: String, bundleIdentifier: String? = nil) {
        id = UUID(); self.name = name; self.path = path; self.bundleIdentifier = bundleIdentifier; isEnabled = true
    }
}
public enum PanelPosition: String, Codable, CaseIterable, Sendable { case menuBar = "Menu Bar", center = "Screen Center", cursor = "Near Cursor" }
public enum AppAppearance: String, Codable, CaseIterable, Sendable { case system = "System", light = "Light", dark = "Dark", tinted = "Tinted", transparent = "Transparent" }
public enum AppTint: String, Codable, CaseIterable, Sendable { case blue, purple, pink, orange, green, graphite }
public struct HotKey: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public var label: String
    public init(keyCode: UInt32 = 49, modifiers: UInt32 = 2048, label: String = "⌥ Space") {
        self.keyCode = keyCode; self.modifiers = modifiers; self.label = label
    }
}
public struct AppSettings: Codable, Equatable, Sendable {
    public var historyEnabled = true
    public var historyLimit = 100
    public var closeAfterCopy = true
    public var closeAfterAction = true
    public var saveHistory = true
    public var showDockIcon = false
    public var panelPosition = PanelPosition.menuBar
    public var appearance = AppAppearance.system
    public var numberShortcuts = true
    public var compactRows = false
    public var pasteOnSelection = true
    public var tint = AppTint.blue
    public var retentionSeconds: Double = 0
    public var clearSystemClipboard = false
    public var hotKey = HotKey()
    public var hasOnboarded = false
    public var excludedBundleIDs = ["com.agilebits.onepassword7", "com.1password.1password", "com.bitwarden.desktop", "com.apple.Passwords", "org.keepassxc.keepassxc", "com.dashlane.Dashlane"]
    public init() {}
    private enum CodingKeys: String, CodingKey { case historyEnabled, historyLimit, closeAfterCopy, closeAfterAction, saveHistory, showDockIcon, panelPosition, appearance, numberShortcuts, compactRows, hotKey, hasOnboarded, excludedBundleIDs, pasteOnSelection, tint, retentionSeconds, clearSystemClipboard }
    public init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        historyEnabled = try values.decodeIfPresent(Bool.self, forKey: .historyEnabled) ?? historyEnabled
        historyLimit = try values.decodeIfPresent(Int.self, forKey: .historyLimit) ?? historyLimit
        closeAfterCopy = try values.decodeIfPresent(Bool.self, forKey: .closeAfterCopy) ?? closeAfterCopy
        closeAfterAction = try values.decodeIfPresent(Bool.self, forKey: .closeAfterAction) ?? closeAfterAction
        saveHistory = try values.decodeIfPresent(Bool.self, forKey: .saveHistory) ?? saveHistory
        showDockIcon = try values.decodeIfPresent(Bool.self, forKey: .showDockIcon) ?? showDockIcon
        panelPosition = try values.decodeIfPresent(PanelPosition.self, forKey: .panelPosition) ?? panelPosition
        appearance = try values.decodeIfPresent(AppAppearance.self, forKey: .appearance) ?? appearance
        numberShortcuts = try values.decodeIfPresent(Bool.self, forKey: .numberShortcuts) ?? numberShortcuts
        compactRows = try values.decodeIfPresent(Bool.self, forKey: .compactRows) ?? compactRows
        hotKey = try values.decodeIfPresent(HotKey.self, forKey: .hotKey) ?? hotKey
        hasOnboarded = try values.decodeIfPresent(Bool.self, forKey: .hasOnboarded) ?? hasOnboarded
        excludedBundleIDs = try values.decodeIfPresent([String].self, forKey: .excludedBundleIDs) ?? excludedBundleIDs
        pasteOnSelection = try values.decodeIfPresent(Bool.self, forKey: .pasteOnSelection) ?? pasteOnSelection
        tint = try values.decodeIfPresent(AppTint.self, forKey: .tint) ?? tint
        retentionSeconds = try values.decodeIfPresent(Double.self, forKey: .retentionSeconds) ?? retentionSeconds
        clearSystemClipboard = try values.decodeIfPresent(Bool.self, forKey: .clearSystemClipboard) ?? clearSystemClipboard
        retentionSeconds = retentionSeconds.isFinite ? max(0, retentionSeconds) : 0
        historyLimit = max(0, historyLimit)
    }
}
public struct Snapshot: Codable, Sendable {
    public var version = 1
    public var items: [ClipboardItem]
    public var apps: [QuickApp]
    public var settings: AppSettings
    public init(items: [ClipboardItem], apps: [QuickApp], settings: AppSettings) {
        self.items = items; self.apps = apps; self.settings = settings
    }
}

public struct LocalStorage: Sendable {
    public let directory: URL
    public var imagesDirectory: URL { directory.appendingPathComponent("Images", isDirectory: true) }
    public var metadataURL: URL { directory.appendingPathComponent("library.json") }
    public init(directory: URL) { self.directory = directory }
    public func prepare() throws {
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
    }
    public func load() throws -> Snapshot? {
        guard FileManager.default.fileExists(atPath: metadataURL.path) else { return nil }
        let snapshot = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: metadataURL))
        guard snapshot.version == 1 else { throw CocoaError(.coderReadCorrupt) }
        return snapshot
    }
    public func save(_ snapshot: Snapshot) throws {
        try prepare()
        let persisted = Snapshot(items: snapshot.items.filter { snapshot.settings.saveHistory || $0.isPinned }, apps: snapshot.apps, settings: snapshot.settings)
        try JSONEncoder().encode(persisted).write(to: metadataURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: metadataURL.path)
    }
    public func imageURL(_ name: String) -> URL? {
        guard name == URL(fileURLWithPath: name).lastPathComponent, name.hasSuffix(".png") else { return nil }
        return imagesDirectory.appendingPathComponent(name)
    }
    public func cleanImages(keeping names: Set<String>) throws {
        guard FileManager.default.fileExists(atPath: imagesDirectory.path) else { return }
        for url in try FileManager.default.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: nil) where !names.contains(url.lastPathComponent) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
