import SwiftUI
#if SWIFT_PACKAGE
import ClipDockCore
#endif

struct PrivacySettingsView: View {
    @ObservedObject var state: AppState
    @ObservedObject var store: ClipboardStore
    var body: some View {
        Section("Private by Design") {
            Label("Your clipboard history is stored locally on this Mac and is never uploaded anywhere.", systemImage: "lock.shield")
            Text("No accounts, analytics, cloud storage, or network search. Saved clips are kept in your user Application Support folder. They are not encrypted by ClipDock; macOS account security and FileVault protect access to your Mac.").font(.caption).foregroundStyle(.secondary)
        }
        Section("Excluded Applications") {
            Text("Capture pauses while these apps are active. Items marked as concealed, transient, or automatically generated are also ignored. macOS does not always identify the app that wrote the clipboard; exclusions are a best-effort safeguard.").font(.caption).foregroundStyle(.secondary)
            ForEach(store.settings.excludedBundleIDs, id: \.self) { id in
                HStack {
                    Text(id).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                    Spacer()
                    Button { store.settings.excludedBundleIDs.removeAll { $0 == id } } label: { Image(systemName: "minus.circle") }.help("Remove exclusion")
                }
            }
            Button("Exclude Application…") { state.launcher.pickApplications(excluded: true) }
        }
    }
}
