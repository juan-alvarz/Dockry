import AppKit
import Carbon.HIToolbox
import DockryCore
import SwiftUI

/// A ⌘Tab-style overlay for switching profiles from the keyboard.
///
/// ⌃⌥Space opens it with the next profile selected. While ⌃⌥ are held, Space moves the
/// selection and letting go switches, so a quick ⌃⌥Space flips between two profiles. If the
/// keys are already up when it opens (or it was opened from the menu), it stays open:
/// arrows/Tab move, 1–9 or Return pick, Esc or a click elsewhere cancels.
final class ProfileSwitcherPanel: NSPanel {
    private let store: ProfileStore
    private let selection = SwitcherSelection()
    private let onChoose: (String) -> Void
    private var choosesOnModifierRelease = false

    private static let holdModifiers: NSEvent.ModifierFlags = [.control, .option]

    init(store: ProfileStore, onChoose: @escaping (String) -> Void) {
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
        hasShadow = false  // the SwiftUI content draws its own
        hidesOnDeactivate = false
        contentView = NSHostingView(rootView: ProfileSwitcherView(store: store, selection: selection) { [weak self] in
            self?.choose(at: $0)
        })
    }

    override var canBecomeKey: Bool { true }

    /// What ⌃⌥Space does: opens the switcher, or moves to the next profile if it's open.
    func showOrAdvance() {
        if isVisible {
            move(by: 1)
            return
        }
        let profiles = store.library.profiles
        let activeIndex = profiles.firstIndex { $0.name == store.active.name } ?? 0
        selection.index = (activeIndex + 1) % profiles.count
        choosesOnModifierRelease = NSEvent.modifierFlags.isSuperset(of: Self.holdModifiers)

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
        if choosesOnModifierRelease && !event.modifierFlags.isSuperset(of: Self.holdModifiers) {
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
    @ObservedObject var selection: SwitcherSelection
    let choose: (Int) -> Void

    private let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(store.library.profiles.enumerated()), id: \.element.name) { index, profile in
                Button { choose(index) } label: {
                    ProfileTile(
                        profile: profile, number: index + 1,
                        isSelected: index == selection.index,
                        isActive: profile.name == store.active.name)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(VisualEffectBackground().clipShape(shape))
        .overlay(shape.strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        .padding(30)  // keeps the shadow inside the panel
    }
}

private struct ProfileTile: View {
    let profile: Profile
    let number: Int
    let isSelected: Bool
    let isActive: Bool

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
            Text(isActive ? "Active" : number <= 9 ? "⌃⌥\(number)" : " ")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(width: 128, height: 144)
        .background(isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.3)) : AnyShapeStyle(.clear), in: shape)
        .overlay(shape.strokeBorder(Color.accentColor, lineWidth: isSelected ? 2 : 0))
        .contentShape(shape)
    }
}
