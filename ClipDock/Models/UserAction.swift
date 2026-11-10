import Foundation

public enum ActionKind: String, Codable, CaseIterable, Sendable { case launch = "Launch app", quit = "Quit app", script = "Shell script", toggle = "ON/OFF scripts" }
public struct UserAction: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var name = "New action"
    public var detail = ""
    public var kind = ActionKind.launch
    public var path = ""
    public var offPath = ""
    public var shortcut: HotKey?
    public init() {}
}
public struct ActionLibrary: Codable, Equatable, Sendable {
    public var version = 1
    public var actions: [UserAction] = []
    public var gameShortcut: HotKey?
    public init() {}
    public static func load(from url: URL) throws -> Self {
        guard FileManager.default.fileExists(atPath: url.path) else { return Self() }
        let value = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        guard value.version == 1, Set(value.actions.map(\.id)).count == value.actions.count else { throw CocoaError(.coderReadCorrupt) }
        return value
    }
    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
