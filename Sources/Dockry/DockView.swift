import AppKit
import DockryCore
import SwiftUI

/// The dock: profile button, the profile's pinned apps, other running apps, then widgets.
struct DockView: View {
    @ObservedObject var store: ProfileStore
    @ObservedObject var runningApps: RunningApps
    let showProfileMenu: () -> Void

    private let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    var body: some View {
        let profile = store.active
        let sections = DockLayout.sections(pinned: profile.pinnedApps, running: runningApps.bundleIDs)

        HStack(spacing: 6) {
            ProfileButton(profile: profile, action: showProfileMenu)
            DockSeparator()
            appIcons(sections.pinned, profile: profile)
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
        .padding(.top, 8)
        .padding(.bottom, 12)  // room for the running-app dots
        .background(VisualEffectBackground().clipShape(shape))
        .overlay(shape.strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .padding(.horizontal, 20)  // keeps the shadow inside the panel
        .padding(.top, 20)
        .padding(.bottom, 6)
    }

    private func appIcons(_ entries: [DockEntry], profile: Profile) -> some View {
        ForEach(entries) { entry in
            let running = runningApps.app(withBundleID: entry.bundleID)
            if let app = AppCatalog.app(bundleID: entry.bundleID, running: running) {
                AppIconView(entry: entry, app: app, runningApp: running, profileName: profile.name, store: store)
            }
        }
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
                .frame(width: 48, height: 48)
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

/// Real behind-window blur; SwiftUI materials only blur content inside the same window.
private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active  // stay blurred while Dockry isn't the active app, which is always
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
