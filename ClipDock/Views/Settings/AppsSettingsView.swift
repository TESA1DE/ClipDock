import SwiftUI
#if SWIFT_PACKAGE
import ClipDockCore
#endif

struct AppsSettingsView: View {
    @ObservedObject var state: AppState
    @ObservedObject var store: ClipboardStore
    var body: some View {
        Section("Quick Apps") {
            if store.apps.isEmpty { Text("Add applications to build your personal launcher.").foregroundStyle(.secondary) }
            ForEach(Array(store.apps.enumerated()), id: \.element.id) { index, app in
                HStack(spacing: 10) {
                    Image(nsImage: state.launcher.icon(app)).resizable().frame(width: 26, height: 26)
                    Toggle(app.name, isOn: Binding(get: { store.apps.first(where: { $0.id == app.id })?.isEnabled ?? false }, set: { value in
                        if let i = store.apps.firstIndex(where: { $0.id == app.id }) { store.apps[i].isEnabled = value }
                    })).toggleStyle(.checkbox)
                    Spacer()
                    Button { store.apps.swapAt(index, index - 1) } label: { Image(systemName: "chevron.up") }.disabled(index == 0).help("Move \(app.name) up")
                    Button { store.apps.swapAt(index, index + 1) } label: { Image(systemName: "chevron.down") }.disabled(index == store.apps.count - 1).help("Move \(app.name) down")
                    Button { store.apps.removeAll { $0.id == app.id } } label: { Image(systemName: "minus.circle") }.help("Remove \(app.name)")
                }
            }
            Button("Add Application…") { state.launcher.pickApplications() }
        }
        Section("Keyboard") {
            Toggle("Use number keys to launch apps", isOn: $store.settings.numberShortcuts)
            Text("When the Apps tab is active, 1–9 launch the first nine enabled applications in your chosen order.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
