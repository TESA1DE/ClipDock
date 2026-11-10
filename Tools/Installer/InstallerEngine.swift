import Foundation

struct InstallError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Copies a complete, uncompressed app bundle. Never touches user history or preferences.
enum InstallerEngine {
    static func verify(_ app: URL) throws {
        guard let bundle = Bundle(url: app), bundle.bundleIdentifier == "com.clipdock.app",
              let binary = bundle.executableURL, FileManager.default.isExecutableFile(atPath: binary.path) else {
            throw InstallError(message: "A valid ClipDock.app was not found next to the installer. Keep the entire installation folder together.")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--verify", "--deep", "--strict", app.path]
        // No output is needed; avoid pipe backpressure on a malformed bundle.
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw InstallError(message: "App integrity verification failed. Copy the folder again, preserving the .app bundle structure and contents.")
        }
    }

    static func install(source: URL, directory: URL, replaceExisting: Bool,
                        beforeCommit: (() throws -> Void)? = nil) throws -> URL {
        let fm = FileManager.default
        let target = directory.appendingPathComponent("ClipDock.app", isDirectory: true)
        guard source.resolvingSymlinksInPath().standardizedFileURL != target.resolvingSymlinksInPath().standardizedFileURL else {
            throw InstallError(message: "This copy is already in the selected folder.")
        }
        try verify(source)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let existing = fm.fileExists(atPath: target.path)
        if existing {
            guard replaceExisting, Bundle(url: target)?.bundleIdentifier == "com.clipdock.app",
                  (try target.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink != true else {
                throw InstallError(message: "ClipDock.app already exists in this folder. Replacement requires confirmation; unrelated files or symbolic links will not be replaced.")
            }
        }
        let token = UUID().uuidString
        let staged = directory.appendingPathComponent(".ClipDock-install-\(token).app", isDirectory: true)
        let backup = directory.appendingPathComponent(".ClipDock-previous-\(token).app", isDirectory: true)
        defer { try? fm.removeItem(at: staged) }
        // FileManager preserves quarantine metadata. The installer never disables Gatekeeper.
        try fm.copyItem(at: source, to: staged)
        try verify(staged)
        var backedUp = false
        do {
            if existing { try fm.moveItem(at: target, to: backup); backedUp = true }
            try beforeCommit?()
            try fm.moveItem(at: staged, to: target)
        } catch {
            if backedUp {
                do { try fm.moveItem(at: backup, to: target) }
                catch {
                    throw InstallError(message: "Update interrupted. The previous version is saved at: \(backup.path). Move it back as ClipDock.app.")
                }
            }
            throw error
        }
        if backedUp { try? fm.removeItem(at: backup) }
        return target
    }

    static func selfTest(source: URL) throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("ClipDock-InstallerTests-" + UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let target = try install(source: source, directory: root, replaceExisting: false)
        try verify(target)
        print("PASS: clean install and bundle verification")
        do {
            _ = try install(source: source, directory: root, replaceExisting: false)
            throw InstallError(message: "TEST FAILED: overwrite accepted without consent")
        } catch let error as InstallError where !error.message.hasPrefix("TEST FAILED") {}
        print("PASS: existing installation requires consent")
        do {
            _ = try install(source: source, directory: root, replaceExisting: true, beforeCommit: {
                throw InstallError(message: "simulated commit failure")
            })
            throw InstallError(message: "TEST FAILED: expected a failed commit")
        } catch let error as InstallError where error.message == "simulated commit failure" {}
        try verify(target)
        print("PASS: failed update restores the original app")
        _ = try install(source: source, directory: root, replaceExisting: true)
        try verify(target)
        print("PASS: confirmed update")
        let leftovers = try fm.contentsOfDirectory(atPath: root.path).filter { $0.hasPrefix(".ClipDock-") }
        guard leftovers.isEmpty else { throw InstallError(message: "TEST FAILED: temporary bundles not cleaned up") }
        let broken = root.appendingPathComponent("Missing.app")
        do {
            _ = try install(source: broken, directory: root, replaceExisting: true)
            throw InstallError(message: "TEST FAILED: missing payload accepted")
        } catch let error as InstallError where !error.message.hasPrefix("TEST FAILED") {}
        try verify(target)
        print("PASS: missing payload leaves installed app intact")
    }
}
