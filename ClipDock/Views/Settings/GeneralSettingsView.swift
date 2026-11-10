import SwiftUI
import ServiceManagement
#if SWIFT_PACKAGE
import ClipDockCore
#endif

struct GeneralSettingsView: View {
    @ObservedObject var store: ClipboardStore
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    var body: some View {
        Section("Startup") {
            Toggle("Launch ClipDock at login", isOn: Binding(get: { loginEnabled }, set: { enabled in
                do {
                    if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    loginEnabled = SMAppService.mainApp.status == .enabled
                    if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
                } catch { store.errorMessage = "Launch at login could not be changed. Run ClipDock from Applications and review System Settings → General → Login Items." }
            }))
            Toggle("Show Dock icon", isOn: $store.settings.showDockIcon)
        }
        Section("Panel") {
            Toggle("Close panel after launching an app", isOn: $store.settings.closeAfterAction)
            Picker("Panel position", selection: $store.settings.panelPosition) {
                ForEach(PanelPosition.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
        }
        Section {
            Text("ClipDock is always available from the menu bar and your global shortcut.").font(.callout).foregroundStyle(.secondary)
        }
    }
}
