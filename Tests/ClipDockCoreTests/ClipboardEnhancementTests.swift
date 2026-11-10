import XCTest
@testable import ClipDockCore

final class ClipboardEnhancementTests: XCTestCase {
    func testCompactAgeBoundaries() {
        let start = Date(timeIntervalSince1970: 100)
        for (seconds, expected) in [(0, "0 secs"), (1, "1 sec"), (59, "59 secs"), (60, "1 min"), (119, "1 min"), (3599, "59 min"), (3600, "1 hr 0 min"), (3661, "1 hr 1 min"), (7199, "1 hr 59 min"), (7200, "2 hr 0 min")] {
            XCTAssertEqual(ClipboardAge.label(createdAt: start, now: start.addingTimeInterval(Double(seconds))), expected)
        }
        XCTAssertEqual(ClipboardAge.label(createdAt: start, now: start.addingTimeInterval(-5)), "0 secs")
    }
    func testExpiryBoundaryAndPinnedPreservation() {
        let now = Date()
        var pin = ClipboardItem(type: .text, content: "pin", createdAt: now.addingTimeInterval(-1000)); pin.isPinned = true
        var history = History(items: [pin, ClipboardItem(type: .text, content: "old", createdAt: now.addingTimeInterval(-300)), ClipboardItem(type: .text, content: "new", createdAt: now.addingTimeInterval(-299))])
        XCTAssertFalse(history.expire(olderThan: 0, now: now))
        XCTAssertTrue(history.expire(olderThan: 300, now: now))
        XCTAssertEqual(Set(history.items.map(\.content)), ["pin", "new"])
        XCTAssertFalse(history.expire(olderThan: 300, now: now))
    }
    func testOldSettingsMigrationPreservesPreferences() throws {
        var old = AppSettings()
        old.appearance = .dark; old.historyLimit = 250; old.hotKey = HotKey(keyCode: 12, modifiers: 2048, label: "⌥ Q")
        old.excludedBundleIDs = ["test.private"]; old.closeAfterCopy = false
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        for key in ["pasteOnSelection", "tint", "retentionSeconds", "clearSystemClipboard"] { json.removeValue(forKey: key) }
        let result = try JSONDecoder().decode(AppSettings.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(result.appearance, .dark)
        XCTAssertEqual(result.hotKey, old.hotKey)
        XCTAssertEqual(result.excludedBundleIDs, old.excludedBundleIDs)
        XCTAssertEqual(result.historyLimit, 250)
        XCTAssertFalse(result.closeAfterCopy)
        XCTAssertTrue(result.pasteOnSelection)
        XCTAssertEqual(result.retentionSeconds, 0)
        XCTAssertFalse(result.clearSystemClipboard)
    }
    func testNewAppearanceAndRetentionRoundTrip() throws {
        for appearance in AppAppearance.allCases {
            var settings = AppSettings(); settings.appearance = appearance; settings.tint = .purple
            settings.retentionSeconds = 900; settings.clearSystemClipboard = true; settings.pasteOnSelection = false
            XCTAssertEqual(try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings)), settings)
        }
    }
}
