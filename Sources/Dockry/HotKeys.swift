import Carbon.HIToolbox

/// System-wide keyboard shortcuts. Carbon's hot key API is old, but it's still how macOS
/// apps register global shortcuts, and unlike event taps it needs no permissions.
@MainActor
final class HotKeys {
    fileprivate var actions: [UInt32: () -> Void] = [:]

    init() {
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(), handleHotKeyEvent, 1, &pressed,
            Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    /// `modifiers` uses Carbon's flags (`controlKey`, `optionKey`, `cmdKey`, `shiftKey`).
    func register(keyCode: UInt16, modifiers: Int, action: @escaping () -> Void) {
        let id = UInt32(actions.count + 1)
        let hotKeyID = EventHotKeyID(signature: OSType(0x444B_5259), id: id)  // 'DKRY'
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr else {
            NSLog("Dockry: couldn't register hot key \(keyCode) (error \(status)); another app may own it")
            return
        }
        actions[id] = action
    }
}

private func handleHotKeyEvent(
    _ handler: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    GetEventParameter(
        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
        nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
    let hotKeys = Unmanaged<HotKeys>.fromOpaque(userData).takeUnretainedValue()
    // Carbon delivers hot key events on the main thread.
    MainActor.assumeIsolated { hotKeys.actions[hotKeyID.id]?() }
    return noErr
}
