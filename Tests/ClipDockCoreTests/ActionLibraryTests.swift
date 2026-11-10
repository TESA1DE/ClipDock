import XCTest
@testable import ClipDockCore
final class ActionLibraryTests: XCTestCase {
    func testActionsRoundTripAndEditDelete() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("actions.json")
        var library = ActionLibrary()
        var action = UserAction(); action.name = "Game helper"; action.kind = .toggle
        action.path = "/tmp/on.sh"; action.offPath = "/tmp/off.command"; action.shortcut = HotKey()
        library.actions = [action]; library.gameShortcut = HotKey(keyCode: 5, modifiers: 256, label: "⌘G")
        try library.save(to: file)
        XCTAssertEqual(try ActionLibrary.load(from: file), library)
        library.actions[0].detail = "Edited"; try library.save(to: file)
        XCTAssertEqual(try ActionLibrary.load(from: file).actions[0].detail, "Edited")
        library.actions.removeAll(); try library.save(to: file)
        XCTAssertTrue(try ActionLibrary.load(from: file).actions.isEmpty)
    }
    func testCorruptOrFutureLibraryIsNotOverwritten() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        for content in ["not json", "{\"version\":2,\"actions\":[]}"] {
            let data = Data(content.utf8); try data.write(to: file)
            XCTAssertThrowsError(try ActionLibrary.load(from: file))
            XCTAssertEqual(try Data(contentsOf: file), data)
        }
    }
    func testDuplicateIDsRejected() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let action = UserAction(); var library = ActionLibrary(); library.actions = [action, action]
        try library.save(to: file)
        XCTAssertThrowsError(try ActionLibrary.load(from: file))
    }
}
