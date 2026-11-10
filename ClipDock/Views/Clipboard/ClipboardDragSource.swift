import AppKit
import SwiftUI

/// Native drag session supports several file URLs and always offers copy, never move.
struct ClipboardDragSource<Content: View>: NSViewRepresentable {
    var height: CGFloat
    var label: String
    var content: Content
    var writers: () -> [NSPasteboardWriting]
    var activate: () -> Void
    var started: () -> Void
    var finished: (NSDragOperation) -> Void

    func makeNSView(context: Context) -> DragView<Content> { DragView(content: content) }
    func updateNSView(_ view: DragView<Content>, context: Context) {
        view.host.rootView = content
        view.writers = writers; view.activate = activate; view.started = started; view.finished = finished
        view.setAccessibilityLabel(label)
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: DragView<Content>, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 370, height: height)
    }
}

final class DragView<Content: View>: NSView, NSDraggingSource {
    let host: NSHostingView<Content>
    var writers: (() -> [NSPasteboardWriting])?
    var activate: (() -> Void)?
    var started: (() -> Void)?
    var finished: ((NSDragOperation) -> Void)?
    private var initialEvent: NSEvent?
    private var dragging = false
    private var activeDragSource: DragView<Content>?
    override var acceptsFirstResponder: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    init(content: Content) {
        host = NSHostingView(rootView: content)
        super.init(frame: .zero)
        addSubview(host)
        host.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([host.leadingAnchor.constraint(equalTo: leadingAnchor), host.trailingAnchor.constraint(equalTo: trailingAnchor), host.topAnchor.constraint(equalTo: topAnchor), host.bottomAnchor.constraint(equalTo: bottomAnchor)])
        setAccessibilityElement(true); setAccessibilityRole(.button)
        focusRingType = .exterior
    }
    required init?(coder: NSCoder) { nil }
    override func hitTest(_ point: NSPoint) -> NSView? { super.hitTest(point) == nil ? nil : self }
    override func accessibilityPerformPress() -> Bool { activate?(); return true }
    override func mouseDown(with event: NSEvent) { initialEvent = event; dragging = false }
    override func mouseUp(with event: NSEvent) {
        defer { initialEvent = nil }
        if initialEvent != nil, !dragging, bounds.contains(convert(event.locationInWindow, from: nil)) { activate?() }
    }
    override func keyDown(with event: NSEvent) {
        if [36, 49].contains(event.keyCode) { activate?() } else { super.keyDown(with: event) }
    }
    override func mouseDragged(with event: NSEvent) {
        guard !dragging, let initialEvent,
              hypot(event.locationInWindow.x - initialEvent.locationInWindow.x, event.locationInWindow.y - initialEvent.locationInWindow.y) > 4,
              let values = writers?(), !values.isEmpty else { return }
        dragging = true
        let preview = NSImage(size: bounds.size)
        if let bitmap = bitmapImageRepForCachingDisplay(in: bounds) {
            cacheDisplay(in: bounds, to: bitmap); preview.addRepresentation(bitmap)
        }
        let items = values.enumerated().map { index, writer in
            let item = NSDraggingItem(pasteboardWriter: writer)
            let offset = CGFloat(index) * 5
            item.setDraggingFrame(bounds.offsetBy(dx: offset, dy: -offset), contents: preview)
            return item
        }
        activeDragSource = self // Keep the source alive if retention removes its row mid-drag.
        started?()
        let session = beginDraggingSession(with: items, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        dragging = false; initialEvent = nil; finished?(operation)
        activeDragSource = nil
    }
}
