import SwiftUI
#if SWIFT_PACKAGE
import ClipDockCore
#endif

struct MainTabView: View {
    @ObservedObject var state: AppState
    @ObservedObject var store: ClipboardStore
    @FocusState private var searchFocused: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "square.on.square.fill").foregroundStyle(.tint)
                Text("ClipDock").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(store.settings.hotKey.label).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                Menu {
                    Button("Actions…") { state.settingsSection = "Actions"; state.openSettings?() }
                    Button("Settings…") { state.openSettings?() }
                    Toggle("Capture Clipboard", isOn: $store.settings.historyEnabled)
                    Divider()
                    Button("Quit ClipDock") { NSApp.terminate(nil) }
                } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).fixedSize().help("ClipDock actions")
            }.padding(.horizontal, 20).padding(.top, 17).padding(.bottom, 14)
            Picker("Section", selection: $state.tab) {
                ForEach(AppState.Tab.allCases, id: \.self) { tab in Text(tab.rawValue).tag(tab) }
            }.pickerStyle(.segmented).labelsHidden().padding(.horizontal, 18).padding(.bottom, 14)
            if state.tab == .clipboard {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search your clipboard", text: $state.query).textFieldStyle(.plain).focused($searchFocused)
                        .accessibilityLabel("Search clipboard")
                    if !state.query.isEmpty { Button { state.query = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(.secondary).help("Clear search") }
                }.padding(12).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10)).padding(.horizontal, 18).padding(.bottom, 12)
                Divider().padding(.horizontal, 18)
                ClipboardListView(state: state, store: store)
            } else { AppLauncherView(state: state, store: store) }
            if let error = store.errorMessage {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                    Text(error).font(.caption).textSelection(.enabled)
                    Button { store.errorMessage = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain).help("Dismiss error")
                }.padding(12).background(.orange.opacity(0.08))
            }
            Divider()
            HStack(spacing: 6) {
                Circle().fill(store.settings.historyEnabled ? Color.green : Color.orange).frame(width: 5, height: 5)
                Text(state.toast ?? (store.settings.historyEnabled ? "On this Mac only" : "Capture paused"))
                Spacer()
                if state.tab == .clipboard {
                    Text(store.settings.pasteOnSelection ? "↑↓ select  ↩ paste" : "↑↓ select  ↩ copy").foregroundStyle(.tertiary)
                    Button("Clear History") { store.clear() }.buttonStyle(.plain).foregroundStyle(.secondary).padding(.leading, 8)
                } else { Button("Manage Apps…") { state.settingsSection = "Apps"; state.openSettings?() }.buttonStyle(.plain) }
            }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 18).padding(.vertical, 13)
        }
        .frame(width: 480, height: 570)
        .background(PanelBackground(appearance: store.settings.appearance, tint: store.settings.tint))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.09)))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onChange(of: state.focusRequest) { _, _ in searchFocused = state.tab == .clipboard }
        .onChange(of: state.tab) { _, tab in searchFocused = tab == .clipboard }
        .onChange(of: state.query) { _, _ in state.selectedID = state.results.first?.id }
        .onAppear { searchFocused = true; state.selectValidItem() }
    }
}

struct WelcomeView: View {
    var shortcut: String
    var complete: (Bool) -> Void
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "square.on.square.fill").font(.system(size: 42)).foregroundStyle(.tint)
            Text("ClipDock").font(.title2.bold())
            Text("Your clipboard and apps,\none shortcut away.").multilineTextAlignment(.center).foregroundStyle(.secondary)
            Text("Press \(shortcut) from any app.").font(.callout)
            HStack {
                Button("Open Settings") { complete(true) }
                Button("Get Started") { complete(false) }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
            Text("Private by design. Everything stays on this Mac.").font(.caption).foregroundStyle(.tertiary)
        }.padding(30).frame(width: 420, height: 340)
    }
}
