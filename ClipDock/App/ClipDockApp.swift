import SwiftUI

@main
struct ClipDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        Settings { SettingsView(state: delegate.state, store: delegate.state.store) }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button("Settings…") { delegate.openSettings() }
                        .keyboardShortcut(",", modifiers: .command)
                }
            }
    }
}
