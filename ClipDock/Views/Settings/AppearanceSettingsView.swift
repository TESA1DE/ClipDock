import SwiftUI
#if SWIFT_PACKAGE
import ClipDockCore
#endif

struct AppearanceSettingsView: View {
    @ObservedObject var store: ClipboardStore
    var body: some View {
        Section("Program Color") {
            Picker("Appearance", selection: $store.settings.appearance) {
                Text("Automatic — follow macOS").tag(AppAppearance.system)
                Text("Light — white").tag(AppAppearance.light)
                Text("Dark — black").tag(AppAppearance.dark)
                Text("Tinted — frosted glass").tag(AppAppearance.tinted)
                Text("Frosted glass").tag(AppAppearance.transparent)
            }
            if store.settings.appearance == .tinted {
                Picker("Tint color", selection: $store.settings.tint) {
                    ForEach(AppTint.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                Text("Softly blurred desktop colors with a subtle tint. Text and controls stay crisp.").font(.caption).foregroundStyle(.secondary)
            }
            if store.settings.appearance == .transparent {
                Text("Translucent frosted glass with a strong background blur, like Safari’s glass surfaces. macOS Reduce Transparency takes priority.").font(.caption).foregroundStyle(.secondary)
            }
            Toggle("Compact clipboard rows", isOn: $store.settings.compactRows)
        }
    }
}
