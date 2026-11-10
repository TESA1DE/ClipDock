import SwiftUI
#if SWIFT_PACKAGE
import ClipDockCore
#endif

struct ClipboardItemView: View {
    var item: ClipboardItem
    var selected: Bool
    var compact: Bool
    var imageURL: URL?
    var copy: () -> Void
    var copyOnly: () -> Void
    var writers: () -> [NSPasteboardWriting]
    var dragStarted: () -> Void
    var dragFinished: (NSDragOperation) -> Void
    var pin: () -> Void
    var delete: () -> Void
    @State private var hovered = false
    var body: some View {
        HStack(spacing: 0) {
            ClipboardDragSource(height: compact ? 50 : 72, label: item.preview, content:
                HStack(spacing: 12) {
                    ClipboardPreviewView(item: item, imageURL: imageURL)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.preview).font(.system(size: 13, weight: .medium)).lineLimit(compact ? 1 : 2).multilineTextAlignment(.leading)
                        if !compact {
                            HStack(spacing: 5) {
                                Text(item.type.label)
                                Text("·")
                                TimelineView(.periodic(from: .now, by: 1)) { context in
                                    Text(ClipboardAge.label(createdAt: item.createdAt, now: context.date))
                                }
                                if item.isPinned { Image(systemName: "pin.fill").font(.system(size: 9)) }
                            }.font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 6)
                }.padding(.vertical, compact ? 9 : 11).padding(.leading, 11).contentShape(Rectangle())
            , writers: writers, activate: copy, started: dragStarted, finished: dragFinished)
            HStack(spacing: 7) {
                Button(action: pin) { Image(systemName: item.isPinned ? "pin.slash" : "pin") }.help(item.isPinned ? "Unpin (⌘P)" : "Pin (⌘P)")
                Button(action: delete) { Image(systemName: "trash") }.help("Delete (⌘⌫)")
            }.buttonStyle(.plain).foregroundStyle(.secondary).font(.system(size: 12))
                .opacity(hovered || selected ? 1 : 0).padding(.trailing, 11)
        }
        .background(selected ? Color.accentColor.opacity(0.13) : hovered ? Color.primary.opacity(0.045) : .clear, in: RoundedRectangle(cornerRadius: 9))
        .onHover { hovered = $0 }
        .contextMenu {
            Button("Copy Only", action: copyOnly)
            Button(item.isPinned ? "Unpin" : "Pin", action: pin)
            if item.type == .url, let url = URL(string: item.content.trimmingCharacters(in: .whitespacesAndNewlines)) {
                Button("Open URL") { NSWorkspace.shared.open(url) }
            }
            if item.type == .file {
                Button("Reveal in Finder") {
                    let paths = item.files.isEmpty ? [(item.content.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).expandingTildeInPath] : item.files
                    NSWorkspace.shared.activateFileViewerSelecting(paths.map { URL(fileURLWithPath: $0) })
                }
            }
            Divider(); Button("Delete", role: .destructive, action: delete)
        }
        .accessibilityElement(children: .contain)
    }
}
