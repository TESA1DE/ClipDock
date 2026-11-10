import XCTest
@testable import ClipDock
final class ActionValidationTests: XCTestCase {
    func testApprovedScriptBytesExecuteWithExitStatus() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("trusted script.sh")
        let task = ActionController.makeScriptProcess(source: "printf done > result.txt; exit 7", url: url)
        try task.run(); task.waitUntilExit()
        XCTAssertEqual(task.terminationStatus, 7)
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("result.txt")), "done")
    }
    func testScriptValidationDoesNotExecuteAndHandlesSpaces() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("test script.command")
        let source = "#!/bin/bash\nprintf 'test'\n"
        try source.write(to: file, atomically: true, encoding: .utf8)
        XCTAssertEqual(try ActionController.readScript(file), source)
        XCTAssertThrowsError(try ActionController.readScript(root))
        try String(repeating: "a", count: 131073).write(to: file, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ActionController.readScript(file))
        try "bad\0script".write(to: file, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ActionController.readScript(file))
    }
}
