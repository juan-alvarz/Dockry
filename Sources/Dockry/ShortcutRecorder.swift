import AppKit
import Carbon.HIToolbox
import DockryCore
import SwiftUI

/// A field for a global keyboard shortcut: click it, then press the keys. Esc cancels, and
/// Delete while recording (or the clear button) removes the shortcut.
struct ShortcutRecorder: View {
    @Binding var shortcut: KeyShortcut?
    @ObservedObject private var hotKeys = HotKeys.shared
    @State private var monitor: Any?
    @State private var hint: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            HStack(spacing: 4) {
                Button(action: toggleRecording) {
                    Text(monitor != nil ? "Type shortcut…" : shortcut?.displayString ?? "Record Shortcut")
                        .frame(minWidth: 110)
                }
                if shortcut != nil && monitor == nil {
                    Button { shortcut = nil } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .help("Remove shortcut")
                }
            }
            if let message = hint ?? shortcut.flatMap({ hotKeys.taken.contains($0) ? "Another app already uses this shortcut." : nil }) {
                Text(message).font(.caption).foregroundStyle(.orange)
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private func toggleRecording() {
        if monitor != nil {
            stopRecording()
            return
        }
        hint = nil
        HotKeys.shared.isSuspended = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            record(event)
            return nil
        }
    }

    private func record(_ event: NSEvent) {
        let flags = UInt64(event.modifierFlags.intersection([.control, .option, .shift, .command]).rawValue)
        switch Int(event.keyCode) {
        case kVK_Escape where flags == 0:
            stopRecording()
        case kVK_Delete where flags == 0, kVK_ForwardDelete where flags == 0:
            shortcut = nil
            stopRecording()
        default:
            let recorded = KeyShortcut(keyCode: event.keyCode, modifierFlags: flags, key: Self.keyName(event))
            guard recorded.isUsableGlobally else {
                hint = "Use at least one of ⌃, ⌥ or ⌘."
                return
            }
            hint = nil
            shortcut = recorded
            stopRecording()
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            HotKeys.shared.isSuspended = false
        }
        monitor = nil
    }

    private static let specialKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "⎋", kVK_Delete: "⌫",
        kVK_ForwardDelete: "⌦", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑",
        kVK_DownArrow: "↓", kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    /// The key's own label, without what ⌥ or ⇧ turn it into.
    private static func keyName(_ event: NSEvent) -> String {
        if let name = specialKeys[Int(event.keyCode)] { return name }
        let characters = event.characters(byApplyingModifiers: []) ?? event.charactersIgnoringModifiers ?? ""
        return characters.uppercased()
    }
}
