import AppKit
import DockryCore
import SwiftUI

/// The dock: profile button, the profile's pinned apps, other running apps, then widgets.
/// Like the system Dock it's as wide as its items and centered; once it would be wider than
/// the screen it scrolls sideways instead.
struct DockView: View {
    @ObservedObject var store: ProfileStore
    @ObservedObject var runningApps: RunningApps
    let showProfileMenu: () -> Void

    /// Height of the panel that holds the dock: the dock plus room above it for its shadow.
    static let panelHeight: CGFloat = 96

    static let iconSize: CGFloat = 48
    private static let itemSpacing: CGFloat = 6
    /// How far a dragged icon moves per place.
    private static let slotWidth = iconSize + itemSpacing

    private let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    /// The pinned icon being dragged to a new place, and how far it has moved.
    @State private var drag: (bundleID: String, distance: CGFloat)?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            items.fixedSize()
            ScrollView(.horizontal, showsIndicators: false) { items }
                .fixedSize(horizontal: false, vertical: true)
                // Fade the ends so the overflow reads as "scroll for more", not as cut off.
                .mask(LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0), .init(color: .black, location: 0.015),
                        .init(color: .black, location: 0.985), .init(color: .clear, location: 1),
                    ],
                    startPoint: .leading, endPoint: .trailing))
        }
        .background(VisualEffectBackground().clipShape(shape))
        .overlay(shape.strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var items: some View {
        let profile = store.active
        let sections = DockLayout.sections(pinned: profile.pinnedApps, running: runningApps.bundleIDs)

        return HStack(spacing: Self.itemSpacing) {
            ProfileButton(profile: profile, action: showProfileMenu)
            DockSeparator()
            pinnedIcons(sections.pinned, profile: profile)
            if !sections.running.isEmpty {
                DockSeparator()
                appIcons(sections.running, profile: profile)
            }
            if !profile.widgets.isEmpty {
                DockSeparator()
                ForEach(profile.widgets, id: \.self) { WidgetView(kind: $0) }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)  // also room for an icon's hover zoom, which a scrolling dock clips
        .padding(.bottom, 12)  // room for the running-app dots
    }

    private func appIcons(_ entries: [DockEntry], profile: Profile) -> some View {
        ForEach(entries) { entry in
            let running = runningApps.app(withBundleID: entry.bundleID)
            if let app = AppCatalog.app(bundleID: entry.bundleID, running: running) {
                AppIconView(entry: entry, app: app, runningApp: running, profileName: profile.name, store: store)
            }
        }
    }

    /// The pinned apps, which can be dragged sideways to a new place like in the system Dock.
    /// While dragging, the others slide over to show where the icon will land.
    private func pinnedIcons(_ entries: [DockEntry], profile: Profile) -> some View {
        // Only the icons that are shown take part, so the positions match what's on screen.
        let shown = entries.filter { AppCatalog.app(bundleID: $0.bundleID, running: runningApps.app(withBundleID: $0.bundleID)) != nil }
        let order = drag.map { Self.reordered(shown, moving: $0.bundleID, by: $0.distance) } ?? shown

        return ForEach(order) { entry in
            let running = runningApps.app(withBundleID: entry.bundleID)
            if let app = AppCatalog.app(bundleID: entry.bundleID, running: running) {
                AppIconView(entry: entry, app: app, runningApp: running, profileName: profile.name, store: store)
                    .offset(x: dragOffset(of: entry, shown: shown, order: order))
                    .zIndex(entry.bundleID == drag?.bundleID ? 1 : 0)
                    // High priority, so letting go after a drag doesn't also click (open) the app.
                    .highPriorityGesture(
                        // Global coordinates, so the icon's own movement doesn't change the reading.
                        DragGesture(minimumDistance: 6, coordinateSpace: .global)
                            .onChanged { drag = (entry.bundleID, $0.translation.width) }
                            .onEnded { value in
                                // Unless the profile changed mid-drag, which would reorder the wrong one.
                                if store.active.name == profile.name {
                                    let final = Self.reordered(shown, moving: entry.bundleID, by: value.translation.width)
                                    store.reorderPins(final.map(\.bundleID))
                                }
                                withAnimation(.spring(duration: 0.25)) { drag = nil }
                            })
            }
        }
        .animation(.spring(duration: 0.25), value: order.map(\.bundleID))
    }

    /// `entries` with the one being dragged moved to where `distance` (in points) puts it.
    private static func reordered(_ entries: [DockEntry], moving bundleID: String, by distance: CGFloat) -> [DockEntry] {
        guard let from = entries.firstIndex(where: { $0.bundleID == bundleID }) else { return entries }
        let to = DockLayout.dropIndex(from: from, slotsMoved: distance / slotWidth, count: entries.count)
        var result = entries
        result.insert(result.remove(at: from), at: to)
        return result
    }

    /// The dragged icon follows the pointer, measured from the place it would land in.
    private func dragOffset(of entry: DockEntry, shown: [DockEntry], order: [DockEntry]) -> CGFloat {
        guard let drag, entry.bundleID == drag.bundleID,
              let from = shown.firstIndex(where: { $0.bundleID == entry.bundleID }),
              let to = order.firstIndex(where: { $0.bundleID == entry.bundleID })
        else { return 0 }
        return drag.distance - CGFloat(to - from) * Self.slotWidth
    }
}

private struct AppIconView: View {
    let entry: DockEntry
    let app: AppCatalog.App
    let runningApp: NSRunningApplication?
    let profileName: String
    let store: ProfileStore

    @State private var isHovered = false

    var body: some View {
        Button {
            // Like the Dock: launches the app, or brings it forward and reopens a window.
            NSWorkspace.shared.openApplication(at: app.url, configuration: NSWorkspace.OpenConfiguration())
        } label: {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: DockView.iconSize, height: DockView.iconSize)
                .scaleEffect(isHovered ? 1.12 : 1, anchor: .bottom)
                .animation(.easeOut(duration: 0.12), value: isHovered)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Circle()
                .fill(.primary.opacity(0.75))
                .frame(width: 4, height: 4)
                .offset(y: 8)
                .opacity(entry.isRunning ? 1 : 0)
        }
        .onHover { isHovered = $0 }
        .help(app.name)
        .contextMenu {
            if entry.isPinned {
                Button("Remove from \(profileName)") { store.unpin(entry.bundleID) }
            } else {
                Button("Keep in \(profileName)") { store.pin(entry.bundleID) }
            }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([app.url]) }
            if let runningApp {
                Divider()
                Button("Quit") { runningApp.terminate() }
            }
        }
    }
}

private struct ProfileButton: View {
    let profile: Profile
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: profile.symbol)
                    .font(.system(size: 17, weight: .semibold))
                Text(profile.name)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
            }
            .frame(width: 56, height: 48)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Switch profile (⌃⌥1–9)")
    }
}

private struct DockSeparator: View {
    var body: some View {
        Rectangle()
            .fill(.primary.opacity(0.2))
            .frame(width: 1, height: 40)
            .padding(.horizontal, 4)
    }
}
