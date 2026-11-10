import AppKit
import Carbon
#if SWIFT_PACKAGE
import ClipDockCore
#endif

@MainActor
final class GlobalHotKeyManager {
    private static var nextID: UInt32 = 0
    private let identifier: UInt32
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var onTrigger: (() -> Void)?
    init() {
        Self.nextID += 1; identifier = Self.nextID
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            return MainActor.assumeIsolated {
                let owner = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                var id = EventHotKeyID()
                guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr, id.signature == 0x434C4950, id.id == owner.identifier else { return OSStatus(eventNotHandledErr) }
                owner.onTrigger?()
                return noErr
            }
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    /// Register the replacement before releasing the working shortcut.
    func register(_ value: HotKey) -> Bool {
        var candidate: EventHotKeyRef?
        let id = EventHotKeyID(signature: 0x434C4950, id: identifier)
        guard RegisterEventHotKey(value.keyCode, value.modifiers, id, GetApplicationEventTarget(), 0, &candidate) == noErr else { return false }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = candidate
        return true
    }
    func stop() {
        if let hotKey { UnregisterEventHotKey(hotKey); self.hotKey = nil }
        if let handler { RemoveEventHandler(handler); self.handler = nil }
    }
}
