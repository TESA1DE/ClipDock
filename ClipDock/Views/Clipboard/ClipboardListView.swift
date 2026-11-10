import SwiftUI
#if SWIFT_PACKAGE
import ClipDockCore
#endif

struct ClipboardListView: View {
    @ObservedObject var state: AppState
    @ObservedObject var store: ClipboardStore
    var body: some View {
        let items = state.results
        if items.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: state.query.isEmpty ? "doc.on.clipboard" : "magnifyingglass").font(.system(size: 32, weight: .light)).foregroundStyle(.tertiary)
                Text(state.query.isEmpty ? "A little less copying twice." : "No matching clips").font(.headline)
                Text(state.query.isEmpty ? "Copy some text, a link, or an image.\nIt’ll be here when you need it." : "Try another word or part of a path.").font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            if index == 0 || item.isPinned != items[index - 1].isPinned {
                                HStack {
                                    Text(item.isPinned ? "PINNED" : "RECENT")
                                    Spacer()
                                    Text("\(items.filter { $0.isPinned == item.isPinned }.count)")
                                }.font(.system(size: 10, weight: .semibold)).tracking(0.7).foregroundStyle(.tertiary).padding(.horizontal, 10).padding(.top, 12).padding(.bottom, 5)
                            }
                            ClipboardItemView(item: item, selected: state.selectedID == item.id, compact: store.settings.compactRows, imageURL: store.imageURL(for: item), copy: { state.copy(item) }, copyOnly: { state.copy(item, allowPaste: false) }, writers: {
                                store.flush()
                                do {
                                    let values = try ClipboardTransfer.writers(for: item, imageURL: store.imageURL(for: item), includeImageFile: true)
                                    store.protectImageForDrag(item)
                                    return values
                                }
                                catch { store.errorMessage = "This saved image is unavailable."; return [] }
                            }, dragStarted: { state.isDragging = true }, dragFinished: { operation in
                                state.isDragging = false
                                store.finishDraggingImage(item)
                                if !operation.isEmpty { state.closePanel?() }
                            }, pin: { store.togglePin(item) }, delete: { store.delete(item) }).id(item.id)
                        }
                    }.padding(.horizontal, 10).padding(.bottom, 12)
                }
                .onChange(of: state.selectedID) { _, id in if let id { proxy.scrollTo(id, anchor: .center) } }
                .onChange(of: store.history.items) { _, _ in state.selectValidItem() }
            }
        }
    }
}
