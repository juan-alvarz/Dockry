import AppKit
import Carbon.HIToolbox
import DockryCore
import SwiftUI

/// A ⌘Tab-style overlay for switching profiles from the keyboard.
///
/// Its shortcut (which the user sets, say ⌃⌥Space) opens it with the next profile selected.
/// While the shortcut's modifiers are held, its key moves the selection and letting go
/// switches, so a quick press flips between two profiles. If the keys are already up when it
/// opens (or it was opened from the menu), it stays open: arrows/Tab move, 1–9 or Return pick,
/// Esc or a click elsewhere cancels.
final class ProfileSwitcherPanel: NSPanel {
    private let store: ProfileStore
    private let selection = SwitcherSelection()
    private let onChoose: (String) -> Void
    private var choosesOnModifierRelease = false
    /// The modifiers of the shortcut that opened it, which choose the profile when let go.
    private var holdModifiers: NSEvent.ModifierFlags = []

    init(store: ProfileStore, profileApps: ProfileApps, onChoose: @escaping (String) -> Void) {
        self.store = store
        self.onChoose = onChoose
        // Non-activating: the panel takes the keyboard without pulling the user's app out of focus.
        super.init(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: true)
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true  // follows the rounded content, since the rest of the window is clear
        hidesOnDeactivate = false
        contentView = NSHostingView(rootView: ProfileSwitcherView(store: store, profileApps: profileApps, selection: selection) { [weak self] in
            self?.choose(at: $0)
        })
    }

    override var canBecomeKey: Bool { true }

    /// Opens the switcher, or moves to the next profile if it's open. `shortcut` is the one
    /// that was pressed, if any.
    func showOrAdvance(holding shortcut: KeyShortcut? = nil) {
        if isVisible {
            move(by: 1)
            return
        }
        let profiles = store.library.profiles
        let activeIndex = profiles.firstIndex { $0.name == store.active.name } ?? 0
        selection.index = (activeIndex + 1) % profiles.count
        holdModifiers = NSEvent.ModifierFlags(rawValue: UInt(shortcut?.modifiers ?? 0))
        choosesOnModifierRelease = !holdModifiers.isEmpty && NSEvent.modifierFlags.isSuperset(of: holdModifiers)

        guard let screen = NSScreen.screens.first, let size = contentView?.fittingSize else { return }
        let origin = CGPoint(
            x: (screen.frame.midX - size.width / 2).rounded(),
            y: (screen.frame.midY - size.height / 2 + screen.frame.height / 8).rounded())
        setFrame(NSRect(origin: origin, size: size), display: true)
        makeKeyAndOrderFront(nil)
    }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_Escape:
            orderOut(nil)
        case kVK_Return, kVK_ANSI_KeypadEnter:
            choose(at: selection.index)
        case kVK_LeftArrow:
            move(by: -1)
        case kVK_RightArrow:
            move(by: 1)
        case kVK_Tab:
            move(by: event.modifierFlags.contains(.shift) ? -1 : 1)
        default:
            if let digit = event.charactersIgnoringModifiers.flatMap({ Int($0) }), digit >= 1 {
                choose(at: digit - 1)
            } else {
                super.keyDown(with: event)
            }
        }
    }

    override func flagsChanged(with event: NSEvent) {
        if choosesOnModifierRelease && !event.modifierFlags.isSuperset(of: holdModifiers) {
            choose(at: selection.index)
        }
        super.flagsChanged(with: event)
    }

    /// Clicking anywhere else cancels.
    override func resignKey() {
        super.resignKey()
        orderOut(nil)
    }

    private func move(by step: Int) {
        let count = store.library.profiles.count
        selection.index = ((selection.index + step) % count + count) % count
    }

    private func choose(at index: Int) {
        let profiles = store.library.profiles
        guard profiles.indices.contains(index) else { return }
        choosesOnModifierRelease = false
        orderOut(nil)
        onChoose(profiles[index].name)
    }
}

@MainActor
private final class SwitcherSelection: ObservableObject {
    @Published var index = 0
}

private struct ProfileSwitcherView: View {
    @ObservedObject var store: ProfileStore
    @ObservedObject var profileApps: ProfileApps
    @ObservedObject var selection: SwitcherSelection
    let choose: (Int) -> Void

    private let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(store.library.profiles.enumerated()), id: \.element.name) { index, profile in
                Button { choose(index) } label: {
                    ProfileTile(
                        profile: profile,
                        isSelected: index == selection.index,
                        isActive: profile.name == store.active.name,
                        isPlaying: profileApps.playingProfiles.contains(profile.name))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(VisualEffectBackground().clipShape(shape))
        .overlay(shape.strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
    }
}

private struct ProfileTile: View {
    let profile: Profile
    let isSelected: Bool
    let isActive: Bool
    let isPlaying: Bool

    private let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: profile.symbol)
                .font(.system(size: 30, weight: .semibold))
                .frame(height: 36)
            Text(profile.name)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
            // A peek at the profile's apps makes it recognizable at a glance.
            HStack(spacing: -4) {
                ForEach(profile.pinnedApps.prefix(5), id: \.self) { bundleID in
                    if let app = AppCatalog.app(bundleID: bundleID, running: nil) {
                        Image(nsImage: app.icon).resizable().frame(width: 20, height: 20)
                    }
                }
            }
            .frame(height: 20)
            Text(isActive ? "Active" : profile.shortcut?.displayString ?? " ")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(width: 128, height: 144)
        .overlay(alignment: .topTrailing) {
            if isPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .help("Playing sound")
            }
        }
        .background(isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.3)) : AnyShapeStyle(.clear), in: shape)
        .overlay(shape.strokeBorder(Color.accentColor, lineWidth: isSelected ? 2 : 0))
        .contentShape(shape)
    }
}
