import SwiftUI
#if SWIFT_PACKAGE
import ClipDockCore
#endif

struct ClipboardPreviewView: View {
    var item: ClipboardItem
    var imageURL: URL?
    @State private var thumbnail: NSImage?
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.045))
            if item.type == .color, let color = color {
                RoundedRectangle(cornerRadius: 6).fill(color).padding(6)
            } else if let thumbnail {
                Image(nsImage: thumbnail).resizable().scaledToFill().frame(width: 36, height: 36).clipped()
            } else { Image(systemName: item.type.symbol).font(.system(size: 16)).foregroundStyle(.secondary) }
        }.frame(width: 36, height: 36).clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: imageURL) {
            guard let imageURL else { return }
            // Files are small downsampled PNGs; thumbnails load only for visible lazy rows.
            thumbnail = NSImage(contentsOf: imageURL)
            if thumbnail == nil {
                try? await Task.sleep(for: .milliseconds(250))
                thumbnail = NSImage(contentsOf: imageURL)
            }
        }
    }
    private var color: Color? {
        var hex = item.content.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
        guard let value = UInt64(hex, radix: 16) else { return nil }
        if hex.count == 8 { return Color(.sRGB, red: Double((value >> 24) & 255) / 255, green: Double((value >> 16) & 255) / 255, blue: Double((value >> 8) & 255) / 255, opacity: Double(value & 255) / 255) }
        return Color(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
}
