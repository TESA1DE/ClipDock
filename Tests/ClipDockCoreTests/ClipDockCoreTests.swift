import XCTest
@testable import ClipDockCore

final class ClipDockCoreTests: XCTestCase {
    func testTypeDetection() {
        for (input, type) in [("https://github.com", ClipboardItemType.url), ("/Users/test/file.txt", .file), ("~/Desktop", .file), ("#F59E0B", .color), ("#abc", .color), ("#FF550080", .color), ("{\"hello\":1}", .json), ("plain text", .text), ("https://", .text), ("#invalid", .text), ("{broken}", .text)] {
            XCTAssertEqual(ClipboardTypeDetector.detect(input), type, input)
        }
    }
    func testDuplicatesReuseIdentityAndPin() {
        var history = History()
        let item = ClipboardItem(type: .text, content: "hello")
        history.insert(item, limit: 100); history.togglePin(item.id)
        history.insert(ClipboardItem(type: .text, content: "other"), limit: 100)
        history.insert(ClipboardItem(type: .text, content: "hello"), limit: 100)
        XCTAssertEqual(history.items.count, 2)
        XCTAssertEqual(history.ordered.first?.id, item.id)
        XCTAssertTrue(history.ordered.first!.isPinned)
    }
    func testConsecutiveDuplicates() {
        var history = History()
        for _ in 0..<10 { history.insert(ClipboardItem(type: .text, content: "same"), limit: 100) }
        XCTAssertEqual(history.items.count, 1)
    }
    func testHistoryLimitAndPinnedPreservation() {
        var history = History()
        let pinned = ClipboardItem(type: .text, content: "keep", createdAt: .distantPast)
        history.insert(pinned, limit: 2); history.togglePin(pinned.id)
        for n in 0..<5 { history.insert(ClipboardItem(type: .text, content: "\(n)", createdAt: Date(timeIntervalSince1970: Double(n))), limit: 2) }
        XCTAssertEqual(history.items.count, 3)
        XCTAssertEqual(Set(history.items.map(\.content)), ["keep", "3", "4"])
        history.clear()
        XCTAssertEqual(history.items.map(\.id), [pinned.id])
        history.clear(includePinned: true)
        XCTAssertTrue(history.items.isEmpty)
    }
    func testUnlimitedAndImageBudget() {
        var history = History()
        for n in 0..<550 { history.insert(ClipboardItem(type: .text, content: "\(n)"), limit: 0) }
        XCTAssertEqual(history.items.count, 550)
        let pinned = ClipboardItem(type: .image, content: "pinned", imageBytes: 100, imageDigest: "pinned")
        history.insert(pinned, limit: 0); history.togglePin(pinned.id)
        history.insert(ClipboardItem(type: .image, content: "old", imageBytes: 60, imageDigest: "old", createdAt: .distantPast), limit: 0, imageBudget: 100)
        history.insert(ClipboardItem(type: .image, content: "new", imageBytes: 60, imageDigest: "new"), limit: 0, imageBudget: 100)
        XCTAssertEqual(Set(history.items.filter { $0.type == .image }.map(\.content)), ["pinned", "new"])
    }
    func testSearchTextURLFileAndAccents() {
        let history = History(items: [ClipboardItem(type: .text, content: "Café meeting notes"), ClipboardItem(type: .url, content: "https://apple.com/support"), ClipboardItem(type: .file, content: "file", files: ["/Users/me/Project/Report.pdf"])])
        XCTAssertEqual(history.search("CAFE notes").count, 1)
        XCTAssertEqual(history.search("apple.com").count, 1)
        XCTAssertEqual(history.search("project pdf").count, 1)
        XCTAssertEqual(history.search("  ").count, 3)
        XCTAssertTrue(history.search("absent").isEmpty)
    }
    func testQuickAppAndSettingsPersistence() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = LocalStorage(directory: directory)
        var first = QuickApp(name: "Example", path: "/Applications/Example.app", bundleIdentifier: "test.example")
        first.isEnabled = false
        let apps = [first, QuickApp(name: "Second", path: "/Applications/Second.app")]
        var settings = AppSettings(); settings.historyLimit = 250; settings.hotKey = HotKey(keyCode: 12, modifiers: 256, label: "⌘ Q")
        try storage.save(Snapshot(items: [], apps: apps, settings: settings))
        let loaded = try XCTUnwrap(storage.load())
        XCTAssertEqual(loaded.apps, apps)
        XCTAssertEqual(loaded.settings, settings)
    }
    func testPinsPersistWithHistoryDisabledAndImageCleanup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = LocalStorage(directory: directory)
        var pinned = ClipboardItem(type: .text, content: "pin"); pinned.isPinned = true
        var settings = AppSettings(); settings.saveHistory = false
        try storage.save(Snapshot(items: [pinned, ClipboardItem(type: .text, content: "ephemeral")], apps: [], settings: settings))
        XCTAssertEqual(try storage.load()?.items, [pinned])
        try Data([1]).write(to: storage.imagesDirectory.appendingPathComponent("stale.png"))
        try Data([2]).write(to: storage.imagesDirectory.appendingPathComponent("keep.png"))
        try storage.cleanImages(keeping: ["keep.png"])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: storage.imagesDirectory.path), ["keep.png"])
        XCTAssertNil(storage.imageURL("../../secret.png"))
    }
    func testCorruptAndFutureStorageFailsWithoutOverwriting() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = LocalStorage(directory: directory); try storage.prepare()
        let corrupt = Data("bad json".utf8); try corrupt.write(to: storage.metadataURL)
        XCTAssertThrowsError(try storage.load())
        XCTAssertEqual(try Data(contentsOf: storage.metadataURL), corrupt)
        var snapshot = Snapshot(items: [], apps: [], settings: AppSettings()); snapshot.version = 99
        try JSONEncoder().encode(snapshot).write(to: storage.metadataURL)
        XCTAssertThrowsError(try storage.load())
    }
}
