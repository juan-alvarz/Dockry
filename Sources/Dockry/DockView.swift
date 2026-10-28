import AppKit
import DockryCore
import SwiftUI

struct DockActions {
    let showProfileMenu: () -> Void
    let openSettings: () -> Void
}

/// The dock: profile button, the profile's pinned apps, other running apps, then widgets.
/// Like the macOS Dock it's as long as its items and centered on its screen edge; once it
/// would be longer than the screen it scrolls instead.
struct DockView: View {
    @ObservedObject var store: ProfileStore
    @ObservedObject var runningApps: RunningApps
    @ObservedObject var settings: SettingsStore
    @ObservedObject var pointer: DockPointer
    let actions: DockActions

    /// The panel's coordinate space, which DockPointer's locations are in.
    static let space = "dockPanel"

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
        .onPreferenceChange(DockItemFramesKey.self) { pointer.itemFrames = $0 }
        .padding(axes == .horizontal ? .horizontal : .vertical, 8)
        .padding(Edge.Set(metrics.position.outerEdge), DockMetrics.margin)
        .offset(pointer.isRevealed ? .zero : hiddenOffset(metrics))
        .animation(.easeInOut(duration: 0.25), value: pointer.isRevealed)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: Alignment(metrics.position.outerEdge))
        .coordinateSpace(name: Self.space)
    }

    private func row(_ metrics: DockMetrics, magnifies: Bool) -> some View {
        let profile = store.active
        let sections = DockLayout.sections(pinned: profile.pinnedApps, running: runningApps.bundleIDs)

        return DockRowLayout(metrics: metrics, pointer: magnifies ? pointerAlongDock(metrics) : nil) {
            DockBackground(settings: settings, openSettings: actions.openSettings)
                .layoutValue(key: DockBackgroundKey.self, value: true)
            ProfileButton(profile: profile, action: actions.showProfileMenu)
            DockSeparator(settings: settings)
            appIcons(sections.pinned, profile: profile)
            if settings.showsUnpinnedApps && !sections.running.isEmpty {
                DockSeparator(settings: settings)
                appIcons(sections.running, profile: profile)
            }
            if !profile.widgets.isEmpty {
                DockSeparator(settings: settings)
                ForEach(profile.widgets, id: \.self) { WidgetView(kind: $0) }
            }
        }
        .background(GeometryReader { geometry in
            Color.clear.preference(key: DockFrameKey.self, value: geometry.frame(in: .named(Self.space)))
        })
        .onPreferenceChange(DockFrameKey.self) { pointer.dockFrame = $0 }
    }

    private func appIcons(_ entries: [DockEntry], profile: Profile) -> some View {
        ForEach(entries) { entry in
            let running = runningApps.app(withBundleID: entry.bundleID)
            if let app = AppCatalog.app(bundleID: entry.bundleID, running: running) {
                AppIconView(
                    entry: entry, app: app, runningApp: running, profileName: profile.name, store: store,
                    isHovered: pointer.hoveredItem == entry.bundleID)
                    .layoutValue(key: MagnifiesKey.self, value: true)
            }
        }
    }

    private func pointerAlongDock(_ metrics: DockMetrics) -> CGFloat? {
        guard let location = pointer.location else { return nil }
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

private struct DockFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct DockItemFramesKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// The blurred shelf behind the items. Right-clicking it shows the dock's own menu.
private struct DockBackground: View {
    @ObservedObject var settings: SettingsStore
    let openSettings: () -> Void
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
        .contextMenu { DockMenu(settings: settings, openSettings: openSettings) }
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
    let isHovered: Bool

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
        .overlay(alignment: Alignment(metrics.position.innerEdge)) {
            if isHovered {
                NameLabel(name: app.name, position: metrics.position)
            }
        }
        .background(GeometryReader { geometry in
            Color.clear.preference(
                key: DockItemFramesKey.self, value: [entry.bundleID: geometry.frame(in: .named(DockView.space))])
        })
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
        .onChange(of: entry.isRunning) { _, isRunning in
            if isRunning {
                isBouncing = false
            }
        }
    }

    /// The dot under a running app.
    private var indicator: some View {
        Circle()
            .fill(.primary.opacity(0.75))
            .frame(width: 4, height: 4)
            .offset(metrics.position.inward(by: -metrics.edgePadding * 0.6))
            .opacity(entry.isRunning && metrics.showsIndicators ? 1 : 0)
    }

    /// Like the Dock: launches the app, or brings it forward and reopens a window. An app
    /// that isn't running yet bounces until it is.
    private func open() {
        NSWorkspace.shared.openApplication(at: app.url, configuration: NSWorkspace.OpenConfiguration())
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
private struct NameLabel: View {
    let name: String
    let position: DockPosition

    var body: some View {
        let label = Text(name)
            .font(.system(size: 13, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.92), in: Capsule())
            .overlay(Capsule().strokeBorder(.primary.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.2), radius: 4, y: 1)
            .fixedSize()
            .allowsHitTesting(false)
        // Each guide puts the label just past the icon's edge instead of over it.
        switch position {
        case .bottom: label.alignmentGuide(.top) { $0[.bottom] + 10 }
        case .left: label.alignmentGuide(.trailing) { $0[.leading] - 10 }
        case .right: label.alignmentGuide(.leading) { $0[.trailing] + 10 }
        }
    }
}

private struct ProfileButton: View {
    let profile: Profile
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
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12 * metrics.unit, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Switch profile (⌃⌥1–9)")
    }
}

/// The line between the dock's sections. Like the macOS Dock's, dragging it resizes the dock.
private struct DockSeparator: View {
    @ObservedObject var settings: SettingsStore
    @Environment(\.dockMetrics) private var metrics
    @State private var dragStart: (mouse: CGPoint, size: Double)?

    var body: some View {
        let isHorizontal = metrics.axis == .horizontal
        let length = metrics.iconSize * 0.8
        Rectangle()
            .fill(.primary.opacity(0.2))
            .frame(width: isHorizontal ? 1 : length, height: isHorizontal ? length : 1)
            .padding(isHorizontal ? .horizontal : .vertical, 4 * metrics.unit)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 1)
                .onChanged { _ in resize() }
                .onEnded { _ in
                    if dragStart != nil {
                        dragStart = nil
                        DockInteraction.shared.end()
                    }
                })
            .help(settings.syncsWithMacDock ? "Dockry follows the macOS Dock’s size" : "Drag to resize the dock")
    }

    /// Follows the pointer in screen coordinates: the window itself resizes during the drag,
    /// which would throw off the gesture's own coordinates.
    private func resize() {
        guard !settings.syncsWithMacDock else { return }
        let mouse = NSEvent.mouseLocation
        if dragStart == nil {
            dragStart = (mouse, settings.own.iconSize)
            DockInteraction.shared.begin()
        }
        guard let dragStart else { return }
        let delta = switch metrics.position {
        case .bottom: mouse.y - dragStart.mouse.y
        case .left: mouse.x - dragStart.mouse.x
        case .right: dragStart.mouse.x - mouse.x
        }
        settings.own.iconSize = (dragStart.size + Double(delta)).rounded().clamped(to: DockSettings.sizeRange)
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
