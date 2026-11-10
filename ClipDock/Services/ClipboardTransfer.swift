import AppKit
#if SWIFT_PACKAGE
import ClipDockCore
#endif

@MainActor
enum ClipboardTransfer {
    static func writers(for item: ClipboardItem, imageURL: URL?, includeImageFile: Bool = false) throws -> [NSPasteboardWriting] {
        if item.type == .image {
            guard let imageURL else { throw CocoaError(.fileNoSuchFile) }
            let image = NSPasteboardItem()
            image.setData(try Data(contentsOf: imageURL), forType: .png)
            if includeImageFile { image.setString(imageURL.absoluteString, forType: .fileURL) }
            return [image]
        }
        if !item.files.isEmpty { return item.files.map { NSURL(fileURLWithPath: $0) } }
        return [item.content as NSString]
    }
}
