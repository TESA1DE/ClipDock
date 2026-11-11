import AppKit
import SwiftUI

final class SettingsWindow: NSWindow {
    init<Content: View>(rootView: Content) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
                   styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                   backing: .buffered, defer: false)
        title = "ClipDock Settings"
        isReleasedWhenClosed = false
        minSize = NSSize(width: 680, height: 520)
        titlebarAppearsTransparent = true
        toolbar = nil
        let container = NSView()
        contentView = container
        let header = OpaqueTitlebarView()
        let body = NSHostingView(rootView: rootView)
        container.addSubview(header)
        container.addSubview(body)
        header.translatesAutoresizingMaskIntoConstraints = false
        body.translatesAutoresizingMaskIntoConstraints = false
        let guide = contentLayoutGuide as! NSLayoutGuide
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            header.topAnchor.constraint(equalTo: container.topAnchor),
            header.bottomAnchor.constraint(equalTo: guide.topAnchor),
            body.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            body.topAnchor.constraint(equalTo: guide.topAnchor),
            body.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
}

private final class OpaqueTitlebarView: NSView {
    override var isOpaque: Bool { true }
    override var mouseDownCanMoveWindow: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
        NSColor.separatorColor.setFill()
        NSRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: 0.5).fill()
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}
