import SwiftUI
#if SWIFT_PACKAGE
import ClipDockCore
#endif

struct AppLauncherView: View {
    @ObservedObject var state: AppState
    @ObservedObject var store: ClipboardStore
    var body: some View {
        if state.enabledApps.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "square.grid.2x2").font(.system(size: 32, weight: .light)).foregroundStyle(.tertiary)
                Text("Your everyday apps, closer.").font(.headline)
                Text("Choose the apps you reach for most.").font(.callout).foregroundStyle(.secondary)
                Button("Add Applications…") { state.launcher.pickApplications() }.buttonStyle(.borderedProminent)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Array(state.enabledApps.enumerated()), id: \.element.id) { index, app in
                        AppItemView(app: app, icon: state.launcher.icon(app), number: store.settings.numberShortcuts && index < 9 ? index + 1 : nil) { state.launch(app) }
                            .contextMenu {
                                Button("Open") { state.launch(app) }
                                Button("Show in Finder") { state.launcher.reveal(app) }
                                Divider()
                                Button("Remove from ClipDock", role: .destructive) { store.apps.removeAll { $0.id == app.id } }
                            }
                    }
                }.padding(18)
            }.frame(maxHeight: .infinity)
        }
    }
}
struct AppItemView: View {
    var app: QuickApp
    var icon: NSImage
    var number: Int?
    var open: () -> Void
    @State private var hovered = false
    var body: some View {
        Button(action: open) {
            HStack(spacing: 10) {
                Image(nsImage: icon).resizable().frame(width: 34, height: 34)
                Text(app.name).font(.system(size: 12, weight: .medium)).lineLimit(2)
                Spacer(minLength: 0)
                if let number { Text("\(number)").font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary) }
            }.padding(12).frame(maxWidth: .infinity, minHeight: 42).contentShape(Rectangle())
                .background(hovered ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain).onHover { hovered = $0 }.help("Open \(app.name)")
    }
}
