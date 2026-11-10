import SwiftUI
#if SWIFT_PACKAGE
import ClipDockCore
#endif

struct SettingsView: View {
    @ObservedObject var state: AppState
    @ObservedObject var store: ClipboardStore
    @Environment(\.colorScheme) private var colorScheme
    private let sections = [("General", "gearshape"), ("Clipboard", "doc.on.clipboard"), ("Apps", "square.grid.2x2"), ("Shortcuts", "keyboard"), ("Actions", "bolt"), ("Appearance", "circle.lefthalf.filled"), ("Privacy", "hand.raised")]
    var body: some View {
        HStack(spacing: 0) {
            List(selection: $state.settingsSection) {
                ForEach(sections, id: \.0) { name, symbol in Label(name, systemImage: symbol).tag(name) }
            }.listStyle(.sidebar).scrollContentBackground(.hidden).frame(width: 170)
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                Text(state.settingsSection).font(.title3.weight(.semibold)).padding(.horizontal, 22).padding(.top, 20)
                Form {
                    switch state.settingsSection {
                    case "General": GeneralSettingsView(store: store)
                    case "Clipboard": ClipboardSettingsView(store: store, pasteService: state.pasteService)
                    case "Apps": AppsSettingsView(state: state, store: store)
                    case "Actions": ActionsSettingsView(controller: state.actions)
                    case "Shortcuts": ShortcutSettingsView(store: store)
                    case "Appearance": AppearanceSettingsView(store: store)
                    default: PrivacySettingsView(state: state, store: store)
                    }
                }.formStyle(.grouped).scrollContentBackground(.hidden)
                if let error = store.errorMessage {
                    HStack(alignment: .top) {
                        Text(error).font(.caption).foregroundStyle(.secondary)
                        Button("Dismiss") { store.errorMessage = nil }
                    }.padding()
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.frame(minWidth: 680, minHeight: 520)
            .background(PanelBackground(appearance: store.settings.appearance == .system ? (colorScheme == .dark ? .dark : .light) : store.settings.appearance, tint: store.settings.tint, radius: 0))
    }
}
