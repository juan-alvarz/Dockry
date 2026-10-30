import Carbon.HIToolbox
import DockryCore

/// System-wide keyboard shortcuts. Carbon's hot key API is old, but it's still how macOS
/// apps register global shortcuts, and unlike event taps it needs no permissions.
/// Dockry has none by default: the user sets them, so they don't clash with other apps'.
@MainActor
final class HotKeys: ObservableObject {
    static let shared = HotKeys()

    /// Shortcuts another app already has, which Dockry couldn't take.
    @Published private(set) var taken: Set<KeyShortcut> = []
    /// Shortcuts set for more than one of Dockry's own actions; only the first one works.
    @Published private(set) var duplicated: [KeyShortcut] = []
    /// While a shortcut is being recorded, so pressing one Dockry already uses records it
    /// instead of running it.
    var isSuspended = false {
        didSet { apply() }
    }

    fileprivate var actions: [UInt32: () -> Void] = [:]
    private var shortcuts: [(KeyShortcut, () -> Void)] = []
    private var refs: [EventHotKeyRef] = []
    private var nextID: UInt32 = 0

    private init() {
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(), handleHotKeyEvent, 1, &pressed,
            Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    /// Replaces all of Dockry's shortcuts.
    func set(_ shortcuts: [(KeyShortcut, () -> Void)]) {
        self.shortcuts = shortcuts
        apply()
    }

    private func apply() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs = []
        actions = [:]
        guard !isSuspended else { return }
        // Only the first of each combination registers; the others aren't another app's.
        var taken = Set<KeyShortcut>()
        let duplicates = KeyShortcut.duplicates(in: shortcuts.map(\.0))
        let duplicated = duplicates.sorted().map { shortcuts[$0].0 }
        if duplicated != self.duplicated {
            self.duplicated = duplicated
        }
        for (index, (shortcut, action)) in shortcuts.enumerated() where shortcut.isUsableGlobally && !duplicates.contains(index) {
            nextID += 1
            let hotKeyID = EventHotKeyID(signature: OSType(0x444B_5259), id: nextID)  // 'DKRY'
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(shortcut.keyCode), Self.carbonModifiers(shortcut), hotKeyID, GetApplicationEventTarget(), 0, &ref)
            guard status == noErr, let ref else {
                NSLog("Dockry: couldn't register \(shortcut.displayString) (error \(status)); another app may own it")
                taken.insert(shortcut)
                continue
            }
            refs.append(ref)
            actions[nextID] = action
        }
        if taken != self.taken {
            self.taken = taken
        }
    }

    private static func carbonModifiers(_ shortcut: KeyShortcut) -> UInt32 {
        let pairs: [(UInt64, Int)] = [
            (KeyShortcut.control, controlKey), (KeyShortcut.option, optionKey),
            (KeyShortcut.shift, shiftKey), (KeyShortcut.command, cmdKey),
        ]
        return UInt32(pairs.filter { shortcut.modifiers & $0.0 != 0 }.reduce(0) { $0 | $1.1 })
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
