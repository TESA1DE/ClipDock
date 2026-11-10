import AppKit

@MainActor
final class ActiveApplicationMonitor {
    private(set) var bundleIdentifier: String?
    private var observer: NSObjectProtocol?
    var didActivate: ((String?) -> Void)?
    init(observeWorkspace: Bool = true) {
        bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard observeWorkspace else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            let id = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            MainActor.assumeIsolated {
                self?.applicationDidChange(to: id)
            }
        }
    }
    func applicationDidChange(to identifier: String?) {
        let previous = bundleIdentifier
        bundleIdentifier = identifier
        didActivate?(previous)
    }
    deinit { if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) } }
}
