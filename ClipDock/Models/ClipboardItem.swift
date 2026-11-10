import Foundation
import CryptoKit

public enum ClipboardItemType: String, Codable, CaseIterable, Sendable {
    case text, url, file, image, color, json
    public var symbol: String {
        switch self {
        case .text: return "text.alignleft"
        case .url: return "link"
        case .file: return "doc"
        case .image: return "photo"
        case .color: return "paintpalette"
        case .json: return "curlybraces"
        }
    }
    public var label: String { rawValue == "url" ? "URL" : rawValue.capitalized }
}

public struct ClipboardItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var type: ClipboardItemType
    public var content: String
    public var files: [String]
    public var createdAt: Date
    public var isPinned: Bool
    public var imageName: String?
    public var imageBytes: Int
    public var fingerprint: String

    public init(type: ClipboardItemType, content: String, files: [String] = [], imageName: String? = nil,
                imageBytes: Int = 0, imageDigest: String? = nil, createdAt: Date = Date()) {
        id = UUID(); self.type = type; self.content = content; self.files = files
        self.createdAt = createdAt; isPinned = false; self.imageName = imageName; self.imageBytes = imageBytes
        fingerprint = Self.digest(Data((type.rawValue + "\0" + (imageDigest ?? content) + "\0" + files.joined(separator: "\0")).utf8))
    }
    public static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    public var preview: String {
        if type == .file, !files.isEmpty {
            return files.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", ")
        }
        let meaningful = content.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return String(meaningful.prefix(2).joined(separator: "  ").prefix(240))
    }
    public func matches(_ query: String) -> Bool {
        let terms = query.split(whereSeparator: \.isWhitespace)
        let haystack = content + " " + files.joined(separator: " ") + " " + preview
        return terms.allSatisfy { haystack.localizedStandardContains(String($0)) }
    }
}

public enum ClipboardTypeDetector {
    public static func detect(_ text: String) -> ClipboardItemType {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.range(of: "^#(?:[0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$", options: .regularExpression) != nil { return .color }
        if !value.contains("\n"), value.hasPrefix("/") || value.hasPrefix("~/") { return .file }
        if let url = URL(string: value), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil,
           !value.contains(where: \.isWhitespace) { return .url }
        if (value.hasPrefix("{") || value.hasPrefix("[")),
           let data = value.data(using: .utf8), (try? JSONSerialization.jsonObject(with: data)) != nil { return .json }
        return .text
    }
}
