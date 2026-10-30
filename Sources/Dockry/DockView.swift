import AppKit
import DockryCore
import SwiftUI

struct DockActions {
    let showProfileMenu: () -> Void
    let openSettings: () -> Void
}

/// The dock: the profile button, then the profile's items (pinned apps, other running apps,
/// widgets and dividers) in the order the user dragged them into.
/// Like the macOS Dock it's as long as its items and centered on its screen edge; once it
/// would be longer than the screen it scrolls instead.
struct DockView: View {
    @ObservedObject var store: ProfileStore
    @ObservedObject var runningApps: RunningApps
    @ObservedObject var profileApps: ProfileApps
    @ObservedObject var settings: SettingsStore
    @ObservedObject var pointer: DockPointer
    let actions: DockActions
    @ObservedObject private var appWindows = AppWindows.shared

    /// The panel's coordinate space, which DockPointer's locations are in.
    static let space = "dockPanel"

    /// The item being dragged to a new place (by element id), and how far it has moved along the dock.
    @State private var drag: (id: String, distance: CGFloat)?

    var body: some View {
        let metrics = DockMetrics(settings.dock)
        let axes: Axis.Set = metrics.axis == .horizontal ? .horizontal : .vertical
        ViewThatFits(in: axes) {
            row(metrics, magnifies: true).fixedSize()
            ScrollView(axes, showsIndicators: false) { row(metrics, magnifies: false) }
                .fixedSize(horizontal: metrics.axis == .vertical, vertical: metrics.axis == .horizontal)
                // Fade the ends so the overflow reads as "scroll for more", not as cut off.
                .mask(LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0), .init(color: .black, location: 0.015),
                        .init(color: .black, location: 0.985), .init(color: .clear, location: 1),
                    ],
                    startPoint: metrics.axis == .horizontal ? .leading : .top,
                    endPoint: metrics.axis == .horizontal ? .trailing : .bottom))
        }
        .environment(\.dockMetrics, metrics)
        .padding(axes == .horizontal ? .horizontal : .vertical, 8)
        .padding(Edge.Set(metrics.position.outerEdge), DockMetrics.margin)
        .offset(pointer.isRevealed ? .zero : hiddenOffset(metrics))
        .animation(.easeInOut(duration: 0.25), value: pointer.isRevealed)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: Alignment(metrics.position.outerEdge))
        .coordinateSpace(name: Self.space)
        .onAppear(perform: acceptDrops)
    }

    private var elements: [DockElement] {
        DockLayout.elements(
            items: store.active.items, running: runningBundleIDs,
            showsUnpinned: settings.showsUnpinnedApps, isShown: isInstalled)
    }

    /// The open apps the active profile shows, in launch order.
    private var runningBundleIDs: [String] {
        runningApps.apps.filter(profileApps.isShown).compactMap(RunningApps.dockID)
    }

    private func isInstalled(_ bundleID: String) -> Bool {
        AppCatalog.app(bundleID: bundleID, running: runningApps.app(withBundleID: bundleID)) != nil
    }

    /// Like the macOS Dock: folders and apps dragged from Finder go in where the dock opened
    /// a gap for them (see DockPanel's DockHostingView).
    private func acceptDrops() {
        let (store, pointer) = (store, pointer)
        let dock = self
        pointer.performDrop = { items in
            let elements = dock.elements
            let index = DockLayout.itemIndex(
                insertingAt: pointer.dropGap ?? elements.count, elements: elements, itemCount: store.active.items.count)
            store.updateActive { profile in
                for (offset, item) in items.enumerated() {
                    profile.insert(item, at: index + offset)
                }
            }
        }
    }

    /// Which element the drop gap goes in front of, while files are dragged over the dock.
    /// While the pointer is in the gap it stays put; otherwise it's in front of the first
    /// element past the pointer.
    private func dropGap(_ elements: [DockElement], _ metrics: DockMetrics) -> Int? {
        guard drag == nil, let location = pointer.dropLocation else { return nil }
        let isHorizontal = metrics.axis == .horizontal
        let along = isHorizontal ? location.x : location.y
        if let current = pointer.dropGap, let frame = pointer.dropGapFrame,
           (isHorizontal ? frame.minX...frame.maxX : frame.minY...frame.maxY).contains(along) {
            return current
        }
        let centers = elements.map { element in
            frame(of: element).map { Double(isHorizontal ? $0.midX : $0.midY) } ?? .infinity
        }
        let gap = DockLayout.dropGap(at: Double(along), centers: centers)
        pointer.dropGap = gap
        return gap
    }

    /// Where something added at `point` (the window's SwiftUI coordinates) goes in the profile's
    /// items: in front of the first element past it along the dock, or after the last. The
    /// end when there's no point.
    private func insertionIndex(at point: CGPoint?, _ metrics: DockMetrics) -> Int {
        let elements = elements
        let itemCount = store.active.items.count
        guard let point else { return itemCount }
        let isHorizontal = metrics.axis == .horizontal
        let centers = elements.map { element in
            frame(of: element).map { Double(isHorizontal ? $0.midX : $0.midY) } ?? .infinity
        }
        let gap = DockLayout.dropGap(at: Double(isHorizontal ? point.x : point.y), centers: centers)
        return DockLayout.itemIndex(insertingAt: gap, elements: elements, itemCount: itemCount)
    }

    /// An element's frame in the dock's space, once it has been laid out.
    private func frame(of element: DockElement) -> CGRect? {
        switch element.content {
        case .app, .folder: pointer.itemFrames[element.id]
        case .widget: pointer.widgetFrames[element.id]
        case .divider: pointer.separatorFrames[element.id]
        }
    }

    private func row(_ metrics: DockMetrics, magnifies: Bool) -> some View {
        let profile = store.active
        let elements = elements
        let lengths = elements.map { Double(length(of: $0, metrics)) }
        // While dragging, the others slide over to show where the dragged item will land.
        let from = drag.flatMap { drag in elements.firstIndex { $0.id == drag.id } }
        let to = from.map { DockLayout.dropIndex(from: $0, distance: Double(drag!.distance), lengths: lengths, spacing: Double(metrics.spacing)) }
        var order = elements
        if let from, let to {
            order.insert(order.remove(at: from), at: to)
        }
        let dragOffset = from.flatMap { from in to.map { to in
            drag!.distance - CGFloat(DockLayout.shift(from: from, to: to, lengths: lengths, spacing: Double(metrics.spacing)))
        } } ?? 0

        let gap = dropGap(elements, metrics)
        // No magnification while dragging: the places an item moves between keep their size.
        let isDragging = drag != nil || pointer.dropLocation != nil
        let isMagnifying = magnifies && !isDragging && pointer.location != nil
        return DockRowLayout(
            metrics: metrics, pointer: magnifies && !isDragging ? pointerAlongDock(metrics) : nil,
            amount: isMagnifying ? 1 : 0
        ) {
            DockBackground(settings: settings, store: store, openSettings: actions.openSettings) { [dock = self] in
                dock.insertionIndex(at: pointer.contextClick, metrics)
            }
                .layoutValue(key: DockBackgroundKey.self, value: true)
            ProfileButton(
                profile: profile, othersPlaying: profileApps.playingProfiles.subtracting([profile.name]).sorted(),
                action: actions.showProfileMenu)
            DockSeparator(settings: settings, pointer: pointer, id: "profile", store: store, itemIndex: nil)
            ForEach(Array(order.enumerated()), id: \.element.id) { index, element in
                if index == gap {
                    dropGapView(metrics)
                }
                let isDragged = element.id == drag?.id
                elementView(element, profile: profile, metrics: metrics, elements: elements, lengths: lengths)
                    .offset(isDragged ? metrics.position.along(dragOffset) : .zero)
                    .zIndex(isDragged ? 1 : 0)
            }
            if gap == order.count {
                dropGapView(metrics)
            }
        }
        .animation(.spring(duration: 0.25), value: order.map(\.id))
        .animation(.spring(duration: 0.25), value: gap)
        .background(FrameReader { pointer.dockFrame = $0 })
        // Only entering and leaving animate; while over the dock, icons follow the pointer.
        .animation(.easeOut(duration: isMagnifying ? 0.14 : 0.22), value: isMagnifying)
    }

    /// The room the dock makes for something dragged from Finder.
    private func dropGapView(_ metrics: DockMetrics) -> some View {
        Color.clear
            .frame(width: metrics.iconSize, height: metrics.iconSize)
            .background(FrameReader { [pointer] in pointer.dropGapFrame = $0 })
    }

    @ViewBuilder
    private func elementView(
        _ element: DockElement, profile: Profile, metrics: DockMetrics, elements: [DockElement], lengths: [Double]
    ) -> some View {
        let move = DockSeparator.Move(
            changed: { dragChanged(element, distance: $0) },
            ended: { dragEnded(element, distance: $0, profile: profile, elements: elements, lengths: lengths, metrics: metrics) })
        switch element.content {
        case .app(let entry):
            // The copy in this profile, when profiles have their own apps.
            let (here, instances) = AppOpening.instances(of: entry.bundleID, runningApps: runningApps, profileApps: profileApps)
            let running = here ?? instances.first
            if let app = AppCatalog.app(bundleID: entry.bundleID, running: running) {
                AppIconView(
                    entry: entry, app: app, runningApp: running, profileName: profile.name, store: store,
                    opening: AppOpening.choose(
                        url: app.url, bundleID: entry.bundleID, here: here, instances: instances,
                        profileApps: profileApps, settings: settings, profile: profile),
                    profileApps: profileApps,
                    itemIndex: element.itemIndex, isHovered: drag == nil && pointer.hoveredItem == entry.bundleID,
                    minimizedCount: running.flatMap { appWindows.minimizedCounts[$0.processIdentifier] } ?? 0,
                    pointer: pointer)
                    .background(FrameReader { [pointer] in pointer.itemFrames[entry.bundleID] = $0 })
                    .onDisappear { [pointer] in pointer.itemFrames[entry.bundleID] = nil }
                    // High priority, so letting go after a drag doesn't also click (open) the app.
                    .highPriorityGesture(dragGesture(move, metrics: metrics))
                    .layoutValue(key: MagnifiesKey.self, value: true)
            }
        case .widget(let kind):
            MagnifiedWidget { WidgetView(kind: kind) }
                .background(FrameReader { [pointer] in pointer.widgetFrames[element.id] = $0 })
                .onDisappear { [pointer] in pointer.widgetFrames[element.id] = nil }
                .contextMenu {
                    if let menu = DockWidget.widget(for: kind).makeMenu {
                        menu()
                        Divider()
                    }
                    Button("Remove \(kind.info.name) from \(profile.name)") {
                        store.updateActive { $0.removeItem(at: element.itemIndex) }
                    }
                    DockEditMenu(store: store, index: element.itemIndex + 1)
                }
                .highPriorityGesture(dragGesture(move, metrics: metrics))
                .layoutValue(key: MagnifiesKey.self, value: true)
        case .folder(let path):
            FolderIconView(
                path: path, isHovered: drag == nil && pointer.hoveredItem == element.id, profileName: profile.name,
                store: store, itemIndex: element.itemIndex)
                .background(FrameReader { [pointer] in pointer.itemFrames[element.id] = $0 })
                .onDisappear { [pointer] in pointer.itemFrames[element.id] = nil }
                .highPriorityGesture(dragGesture(move, metrics: metrics))
                .layoutValue(key: MagnifiesKey.self, value: true)
        case .divider:
            DockSeparator(settings: settings, pointer: pointer, id: element.id, store: store, itemIndex: element.itemIndex, move: move)
        }
    }

    /// Dragging along the dock moves an item; global coordinates, so the item's own movement
    /// doesn't change the reading.
    private func dragGesture(_ move: DockSeparator.Move, metrics: DockMetrics) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .global)
            .onChanged { move.changed(Self.distance($0.translation, along: metrics.axis)) }
            .onEnded { move.ended(Self.distance($0.translation, along: metrics.axis)) }
    }

    private func dragChanged(_ element: DockElement, distance: CGFloat) {
        if drag == nil {
            DockInteraction.shared.begin()  // an auto-hiding dock stays up
        }
        drag = (element.id, distance)
    }

    private func dragEnded(
        _ element: DockElement, distance: CGFloat, profile: Profile, elements: [DockElement], lengths: [Double], metrics: DockMetrics
    ) {
        // Unless the profile changed mid-drag, which would move the wrong item.
        if store.active.items == profile.items, let from = elements.firstIndex(where: { $0.id == element.id }) {
            let to = DockLayout.dropIndex(from: from, distance: Double(distance), lengths: lengths, spacing: Double(metrics.spacing))
            let items = DockLayout.items(profile.items, afterMoving: from, to: to, in: elements)
            store.updateActive { $0.items = items }
        }
        withAnimation(.spring(duration: 0.25)) { drag = nil }
        DockInteraction.shared.end()
    }

    /// An element's unmagnified length along the dock. Only app icons magnify, so the others'
    /// measured frames are already that.
    private func length(of element: DockElement, _ metrics: DockMetrics) -> CGFloat {
        let frame: CGRect? = switch element.content {
        case .app, .folder: nil
        case .widget: pointer.widgetFrames[element.id]
        case .divider: pointer.separatorFrames[element.id]
        }
        guard let frame else { return metrics.iconSize }
        return metrics.axis == .horizontal ? frame.width : frame.height
    }

    private static func distance(_ translation: CGSize, along axis: Axis) -> CGFloat {
        axis == .horizontal ? translation.width : translation.height
    }

    private func pointerAlongDock(_ metrics: DockMetrics) -> CGFloat? {
        guard let location = pointer.location ?? pointer.lastLocation else { return nil }
        return metrics.axis == .horizontal
            ? location.x - pointer.dockFrame.minX
            : location.y - pointer.dockFrame.minY
    }

    /// Far enough past the screen edge that the shadow goes too.
    private func hiddenOffset(_ metrics: DockMetrics) -> CGSize {
        let distance = metrics.thickness + DockMetrics.margin + 20
        switch metrics.position {
        case .bottom: return CGSize(width: 0, height: distance)
        case .left: return CGSize(width: -distance, height: 0)
        case .right: return CGSize(width: distance, height: 0)
        }
    }
}

/// Reports a view's frame in the dock window's coordinates whenever it changes, for
/// DockPointer. (Not a preference: those don't reliably come out of ViewThatFits.)
private struct FrameReader: View {
    let changed: (CGRect) -> Void

    var body: some View {
        GeometryReader { geometry in
            let frame = geometry.frame(in: .named(DockView.space))
            Color.clear
                .onAppear { changed(frame) }
                .onChange(of: frame) { _, frame in changed(frame) }
        }
    }
}

/// A widget that grows with magnification, as app icons do. Widgets lay themselves out at a
/// fixed size from the dock's metrics, so this measures that size, offers it to the dock's
/// layout as its own, and draws the widget scaled to whatever size the layout gives it.
private struct MagnifiedWidget<Content: View>: View {
    @ViewBuilder let content: Content
    @State private var natural: CGSize?

    var body: some View {
        GeometryReader { proxy in
            let scale = natural.map { $0.width > 0 ? proxy.size.width / $0.width : 1 } ?? 1
            content
                .fixedSize()
                .background(GeometryReader { inner in
                    Color.clear
                        .onAppear { natural = inner.size }
                        .onChange(of: inner.size) { _, size in natural = size }
                })
                .scaleEffect(scale, anchor: .topLeading)
        }
        // Ideal, not fixed: the layout proposes the magnified size, as it does to icons.
        .frame(idealWidth: natural?.width, idealHeight: natural?.height)
    }
}

/// The blurred shelf behind the items. Right-clicking it shows the dock's own menu.
private struct DockBackground: View {
    @ObservedObject var settings: SettingsStore
    let store: ProfileStore
    let openSettings: () -> Void
    /// Where in the profile's items the spot last right-clicked is.
    let clickedIndex: () -> Int
    @Environment(\.dockMetrics) private var metrics

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: max(10, 20 * metrics.unit), style: .continuous)
        ZStack {
            // AppKit's blur view would take the right-click itself, before SwiftUI's menu.
            VisualEffectBackground().clipShape(shape).allowsHitTesting(false)
            shape.fill(Color.black.opacity(0.001))
        }
        .overlay(shape.strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.25), radius: 12, y: metrics.position == .bottom ? 4 : 0)
        .contextMenu {
            DockMenu(settings: settings, openSettings: openSettings)
            DockEditMenu(store: store, index: clickedIndex)
        }
    }
}

/// The dock's right-click menu, like the macOS Dock's.
struct DockMenu: View {
    @ObservedObject var settings: SettingsStore
    let openSettings: () -> Void

    var body: some View {
        if settings.syncsWithMacDock {
            Button("Following the macOS Dock’s Settings") {}.disabled(true)
        } else {
            Button(settings.own.magnifies ? "Turn Magnification Off" : "Turn Magnification On") {
                settings.own.magnifies.toggle()
            }
            Button(settings.own.autohides ? "Turn Hiding Off" : "Turn Hiding On") {
                settings.own.autohides.toggle()
            }
            Picker("Position on Screen", selection: $settings.own.position) {
                ForEach(DockPosition.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
        }
        Divider()
        Button("Dock Settings…", action: openSettings)
    }
}

private struct AppIconView: View {
    let entry: DockEntry
    let app: AppCatalog.App
    let runningApp: NSRunningApplication?
    let profileName: String
    let store: ProfileStore
    let opening: AppOpening
    let profileApps: ProfileApps
    /// The profile item it comes from (for an app that isn't pinned, the open apps' place).
    let itemIndex: Int
    let isHovered: Bool
    /// Its windows in the Dock's minimized windows, which a yellow dot shows.
    let minimizedCount: Int
    let pointer: DockPointer

    @Environment(\.dockMetrics) private var metrics
    @State private var isBouncing = false
    @State private var bounceHeight: CGFloat = 0

    var body: some View {
        Button(action: open) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                // The dock's layout proposes a bigger size while magnifying.
                .frame(idealWidth: metrics.iconSize, idealHeight: metrics.iconSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(app.name)
        .offset(metrics.position.inward(by: bounceHeight))
        .overlay(alignment: Alignment(metrics.position.outerEdge)) { indicator }
        .overlay {
            // With minimized windows, the name comes with the app's windows to bring back.
            if isHovered, minimizedCount > 0, let runningApp {
                WindowList(app: runningApp, name: app.name, position: metrics.position, pointer: pointer)
            } else if isHovered {
                NameLabel(name: app.name, position: metrics.position)
            }
        }
        .contextMenu {
            if entry.isPinned {
                Button("Remove from \(profileName)") { store.unpin(entry.bundleID) }
            } else {
                // Where it is now: just before the other open apps.
                Button("Keep in \(profileName)") { store.updateActive { $0.insert(.app(entry.bundleID), at: itemIndex) } }
            }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([app.url]) }
            if let runningApp {
                Divider()
                Button("Quit") { AppQuitter.quit(runningApp) }
            }
            DockEditMenu(store: store, index: itemIndex + 1)
        }
        .onChange(of: entry.isRunning) { _, isRunning in
            if isRunning {
                isBouncing = false
            }
        }
    }

    /// The dot under a running app, and a yellow one beside it while it has minimized windows.
    private var indicator: some View {
        let dots = Group {
            Circle()
                .fill(.primary.opacity(0.75))
                .frame(width: 4, height: 4)
            if minimizedCount > 0 {
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 4, height: 4)
                    .help(minimizedCount == 1 ? "1 minimized window" : "\(minimizedCount) minimized windows")
            }
        }
        return Group {
            if metrics.axis == .horizontal {
                HStack(spacing: 3) { dots }
            } else {
                VStack(spacing: 3) { dots }
            }
        }
        .offset(metrics.position.inward(by: -metrics.edgePadding * 0.6))
        .opacity(entry.isRunning && metrics.showsIndicators ? 1 : 0)
    }

    /// Like the Dock: launches the app, or brings it forward and reopens a window. An app
    /// that isn't running yet bounces until it is.
    private func open() {
        opening.perform(profileApps)
        guard metrics.animatesLaunch, !entry.isRunning, !isBouncing else { return }
        isBouncing = true
        Task {
            for _ in 0..<6 where isBouncing {
                withAnimation(.easeOut(duration: 0.3)) { bounceHeight = metrics.iconSize * 0.5 }
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(.easeIn(duration: 0.3)) { bounceHeight = 0 }
                try? await Task.sleep(for: .milliseconds(380))
            }
            isBouncing = false
        }
    }
}

/// The app's name, shown next to the hovered icon on the side facing the screen's middle.
/// Used as an overlay on the icon, whose size it reads to stay just clear of it.
struct NameLabel: View {
    let name: String
    let position: DockPosition

    var body: some View {
        IconCallout(position: position) {
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.92), in: Capsule())
                .overlay(Capsule().strokeBorder(.primary.opacity(0.12), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 1)
        }
        .allowsHitTesting(false)
    }
}

/// Places its content next to the icon it overlays, on the side facing the screen's middle.
private struct IconCallout<Content: View>: View {
    let position: DockPosition
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { icon in
            let gap: CGFloat = 10
            // A zero-size anchor just past the icon's edge; the content grows away from it.
            let (anchor, alignment): (CGPoint, Alignment) = switch position {
            case .bottom: (CGPoint(x: icon.size.width / 2, y: -gap), .bottom)
            case .left: (CGPoint(x: icon.size.width + gap, y: icon.size.height / 2), .leading)
            case .right: (CGPoint(x: -gap, y: icon.size.height / 2), .trailing)
            }
            content
                .fixedSize()
                .frame(width: 0, height: 0, alignment: alignment)
                .position(anchor)
        }
    }
}

/// The hovered app's name and its windows, minimized ones marked; clicking one brings it
/// forward, out of the Dock if it's minimized. The pointer can move onto it without the
/// dock losing the hover (see DockPointer.calloutFrame).
private struct WindowList: View {
    let app: NSRunningApplication
    let name: String
    let position: DockPosition
    let pointer: DockPointer
    @State private var windows: [AppWindows.Window] = []

    var body: some View {
        IconCallout(position: position) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.bottom, 2)
                ForEach(Array(windows.prefix(8).enumerated()), id: \.offset) { _, window in
                    WindowRow(window: window) { AppWindows.shared.show(window.element, of: app) }
                }
            }
            .padding(6)
            .frame(width: 240, alignment: .leading)
            .background(VisualEffectBackground().clipShape(RoundedRectangle(cornerRadius: 10)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.primary.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
            .background(FrameReader { [pointer] in pointer.calloutFrame = $0 })
            .onDisappear { [pointer] in pointer.calloutFrame = nil }
        }
        .onAppear { windows = AppWindows.shared.windows(of: app.processIdentifier) }
    }
}

private struct WindowRow: View {
    let window: AppWindows.Window
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(window.isMinimized ? Color.yellow : .clear)
                    .frame(width: 6, height: 6)
                Text(window.title.isEmpty ? "Untitled" : window.title)
                    .lineLimit(1)
                    .foregroundStyle(window.isMinimized ? .secondary : .primary)
                Spacer(minLength: 0)
            }
            .font(.system(size: 12))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isHovered ? Color.accentColor.opacity(0.25) : .clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(window.isMinimized ? "Minimized" : "")
    }
}

private struct ProfileButton: View {
    let profile: Profile
    /// Other profiles with an app playing sound, which a badge points out.
    let othersPlaying: [String]
    let action: () -> Void
    @Environment(\.dockMetrics) private var metrics

    var body: some View {
        let showsName = metrics.axis == .horizontal && metrics.iconSize >= 36
        Button(action: action) {
            VStack(spacing: 3 * metrics.unit) {
                Image(systemName: profile.symbol)
                    .font(.system(size: 17 * metrics.unit, weight: .semibold))
                if showsName {
                    Text(profile.name)
                        .font(.system(size: 10 * metrics.unit, weight: .semibold))
                        .lineLimit(1)
                }
            }
            .frame(width: showsName ? 56 * metrics.unit : metrics.iconSize, height: metrics.iconSize)
            .foregroundStyle(textStyle)
            .background(fillStyle, in: RoundedRectangle(cornerRadius: 12 * metrics.unit, style: .continuous))
            .contentShape(Rectangle())
            .overlay(alignment: .topLeading) {
                if profile.freshApps {
                    FreshAppsBadge()
                        .font(.system(size: 7 * metrics.unit, weight: .bold))
                        .padding(3 * metrics.unit)
                        .background(.regularMaterial, in: Circle())
                        .offset(x: -4 * metrics.unit, y: -4 * metrics.unit)
                }
            }
            .overlay(alignment: .topTrailing) {
                if !othersPlaying.isEmpty {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 8 * metrics.unit, weight: .bold))
                        .padding(3 * metrics.unit)
                        .background(.regularMaterial, in: Circle())
                        .offset(x: 4 * metrics.unit, y: -4 * metrics.unit)
                }
            }
        }
        .buttonStyle(.plain)
        .help(othersPlaying.isEmpty ? "Switch profile" : "Switch profile. Playing sound: \(othersPlaying.joined(separator: ", "))")
    }

    private var fillStyle: AnyShapeStyle {
        profile.color.flatMap(Color.init(hex:)).map { AnyShapeStyle($0.gradient) } ?? AnyShapeStyle(.quaternary)
    }

    private var textStyle: AnyShapeStyle {
        guard let color = profile.color else { return AnyShapeStyle(.primary) }
        return HexColor.prefersLightText(color) ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.black.opacity(0.8))
    }
}

extension Color {
    /// From "#RRGGBB", as profiles store colors.
    init?(hex: String) {
        guard let (red, green, blue) = HexColor.components(hex) else { return nil }
        self.init(red: red, green: green, blue: blue)
    }

    /// As "#RRGGBB", in sRGB.
    var hexString: String? {
        guard let color = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        return HexColor.string(red: color.redComponent, green: color.greenComponent, blue: color.blueComponent)
    }
}

/// The line between groups of items. Like the macOS Dock's, dragging it across the dock
/// resizes the dock; dragging it along the dock moves it, except the one after the profile
/// button, which stays put.
private struct DockSeparator: View {
    struct Move {
        let changed: (CGFloat) -> Void
        let ended: (CGFloat) -> Void
    }

    private enum Drag { case resize, move }

    @ObservedObject var settings: SettingsStore
    let pointer: DockPointer
    let id: String
    let store: ProfileStore
    /// Its place in the profile's items; nil for the one after the profile button.
    let itemIndex: Int?
    var move: Move?
    @Environment(\.dockMetrics) private var metrics
    @State private var drag: Drag?

    var body: some View {
        let isHorizontal = metrics.axis == .horizontal
        let length = metrics.iconSize * 0.8
        Rectangle()
            .fill(.primary.opacity(0.2))
            .frame(width: isHorizontal ? 1 : length, height: isHorizontal ? length : 1)
            .padding(isHorizontal ? .horizontal : .vertical, 4 * metrics.unit)
            .contentShape(Rectangle())
            .background(FrameReader { [pointer, id] in pointer.separatorFrames[id] = $0 })
            .onDisappear { [pointer, id] in pointer.separatorFrames[id] = nil }
            .gesture(DragGesture(minimumDistance: 3, coordinateSpace: .global)
                .onChanged { value in
                    let along = isHorizontal ? value.translation.width : value.translation.height
                    let across = isHorizontal ? value.translation.height : value.translation.width
                    if drag == nil {
                        drag = move != nil && abs(along) > abs(across) ? .move : .resize
                    }
                    if drag == .move { move?.changed(along) } else { pointer.resize(settings) }
                }
                .onEnded { value in
                    if drag == .move {
                        move?.ended(isHorizontal ? value.translation.width : value.translation.height)
                    } else {
                        pointer.endResize()
                    }
                    drag = nil
                })
            .help(Text(help))
            .contextMenu {
                if let itemIndex {
                    Button("Remove Divider") { store.updateActive { $0.removeItem(at: itemIndex) } }
                }
                DockEditMenu(store: store, index: itemIndex.map { $0 + 1 } ?? 0)
            }
    }

    private var help: String {
        let resize = settings.syncsWithMacDock ? "Dockry follows the macOS Dock’s size" : "Drag to resize the dock"
        return move == nil ? resize : "\(resize). Drag along the dock to move the divider."
    }
}

/// Adding to the dock at `index` in the profile's items, in the right-click menus of its items.
struct DockEditMenu: View {
    let store: ProfileStore
    /// Read when an item is chosen: the background's depends on where it was right-clicked.
    private let insertionIndex: () -> Int

    init(store: ProfileStore, index: Int) {
        self.init(store: store) { index }
    }

    init(store: ProfileStore, index: @escaping () -> Int) {
        self.store = store
        insertionIndex = index
    }

    var body: some View {
        let missing = DockWidget.all.filter { !store.active.widgets.contains($0.kind) }
        Divider()
        Button("Add Divider") { store.updateActive { $0.insert(.divider, at: insertionIndex()) } }
        Button("Add Folder…") { addFolder() }
        if !missing.isEmpty {
            Menu("Add Widget") {
                ForEach(missing, id: \.kind) { widget in
                    Button(widget.info.name) { store.updateActive { $0.insert(.widget(widget.kind), at: insertionIndex()) } }
                }
            }
        }
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        panel.prompt = "Add to Dock"
        NSApp.activate(ignoringOtherApps: true)  // a panel from a background app opens behind
        let index = insertionIndex()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.updateActive { $0.insert(.folder(url.path), at: index) }
    }
}

extension DockPosition {
    var title: String {
        switch self {
        case .left: "Left"
        case .bottom: "Bottom"
        case .right: "Right"
        }
    }

    /// An offset along the dock.
    func along(_ distance: CGFloat) -> CGSize {
        isVertical ? CGSize(width: 0, height: distance) : CGSize(width: distance, height: 0)
    }

    /// An offset toward the middle of the screen (negative: toward the screen edge).
    func inward(by distance: CGFloat) -> CGSize {
        switch self {
        case .bottom: CGSize(width: 0, height: -distance)
        case .left: CGSize(width: distance, height: 0)
        case .right: CGSize(width: -distance, height: 0)
        }
    }
}

extension Alignment {
    init(_ edge: Edge) {
        switch edge {
        case .top: self = .top
        case .bottom: self = .bottom
        case .leading: self = .leading
        case .trailing: self = .trailing
        }
    }
}
