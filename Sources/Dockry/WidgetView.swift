import AppKit
import DockryCore
import SwiftUI

struct WidgetView: View {
    let kind: WidgetKind

    var body: some View {
        switch kind {
        case .clock:
            TimelineView(.everyMinute) { ClockWidget(date: $0.date) }
        case .date:
            TimelineView(.everyMinute) { DateWidget(date: $0.date) }
        case .spotify:
            SpotifyWidget()
        case .users:
            UsersWidget()
        case .clipboard:
            ClipboardWidget()
        }
    }
}

extension WidgetKind {
    var title: String {
        switch self {
        case .clock: "Clock"
        case .date: "Calendar"
        case .spotify: "Spotify"
        case .users: "Switch User"
        case .clipboard: "Clipboard"
        }
    }

    var symbol: String {
        switch self {
        case .clock: "clock"
        case .date: "calendar"
        case .spotify: "music.note"
        case .users: "person.2"
        case .clipboard: "list.clipboard"
        }
    }
}

/// The rounded tile widgets sit on.
private struct WidgetTile: ViewModifier {
    @Environment(\.dockMetrics) private var metrics

    func body(content: Content) -> some View {
        content.background(.quaternary, in: RoundedRectangle(cornerRadius: 12 * metrics.unit, style: .continuous))
    }
}

private extension View {
    func widgetTile() -> some View { modifier(WidgetTile()) }
}

/// The time. Clicking it opens the Clock app.
private struct ClockWidget: View {
    let date: Date
    @Environment(\.dockMetrics) private var metrics

    var body: some View {
        let u = metrics.unit
        Button(action: openClock) {
            Text(date, format: .dateTime.hour().minute())
                .font(.system(size: (metrics.axis == .vertical ? 12 : 15) * u, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, (metrics.axis == .vertical ? 3 : 10) * u)
                .frame(
                    width: metrics.axis == .vertical ? metrics.iconSize : nil,
                    height: metrics.iconSize)
                .frame(minWidth: metrics.axis == .vertical ? nil : 72 * u)
                .widgetTile()
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Open Clock")
    }

    private func openClock() {
        if let clock = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.clock") {
            NSWorkspace.shared.openApplication(at: clock, configuration: NSWorkspace.OpenConfiguration())
        } else if let settings = URL(string: "x-apple.systempreferences:com.apple.Date-Time-Settings.extension") {
            NSWorkspace.shared.open(settings)
        }
    }
}

/// A calendar-style tile: month on top, day of the month below. Clicking it shows the month.
private struct DateWidget: View {
    let date: Date
    @Environment(\.dockMetrics) private var metrics
    @State private var showsCalendar = false

    var body: some View {
        let u = metrics.unit
        Button { showsCalendar.toggle() } label: {
            VStack(spacing: 0) {
                Text(date, format: .dateTime.month(.abbreviated))
                    .textCase(.uppercase)
                    .font(.system(size: 9 * u, weight: .bold))
                    .foregroundStyle(.red)
                Text(date, format: .dateTime.day())
                    .font(.system(size: 22 * u, weight: .medium, design: .rounded))
            }
            .frame(width: metrics.iconSize, height: metrics.iconSize)
            .widgetTile()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dockPopover(isPresented: $showsCalendar) { CalendarPopover() }
        .onAppear { ScreenshotHook.openPopoverIfRequested("calendar") { showsCalendar = true } }
    }
}

/// Now playing in Spotify, with previous / play-pause / next. Clicking the song opens the
/// player, with search. In a dock on the side of the screen it's just the album art.
private struct SpotifyWidget: View {
    // Owned by the widget, so Spotify is only watched (and asked for permission) while a
    // profile with this widget is showing.
    @StateObject private var player = SpotifyPlayer()
    @Environment(\.dockMetrics) private var metrics
    @State private var showsPlayer = false

    var body: some View {
        let u = metrics.unit
        Group {
            if metrics.axis == .vertical {
                Button { showsPlayer.toggle() } label: {
                    SpotifyArtwork(url: player.track?.artworkURL, size: metrics.iconSize - 8 * u)
                        .frame(width: metrics.iconSize, height: metrics.iconSize)
                        .widgetTile()
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(player.track.map { "\($0.title) — \($0.artist)" } ?? "Spotify")
            } else {
                HStack(spacing: 8 * u) {
                    Button { showsPlayer.toggle() } label: {
                        HStack(spacing: 8 * u) {
                            SpotifyArtwork(url: player.track?.artworkURL, size: 36 * u)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(player.track?.title ?? "Spotify")
                                    .font(.system(size: 12 * u, weight: .semibold))
                                Text(player.track?.artist ?? "Not playing")
                                    .font(.system(size: 11 * u))
                                    .foregroundStyle(.secondary)
                            }
                            .lineLimit(1)
                            .frame(width: 112 * u, alignment: .leading)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Show player and search")
                    HStack(spacing: 0) {
                        control("backward.fill") { player.previous() }
                        control(player.track?.isPlaying == true ? "pause.fill" : "play.fill") { player.playPause() }
                        control("forward.fill") { player.next() }
                    }
                }
                .padding(.horizontal, 6 * u)
                .frame(height: metrics.iconSize)
                .widgetTile()
            }
        }
        .dockPopover(isPresented: $showsPlayer) { SpotifyPopover(player: player) }
        .onAppear { ScreenshotHook.openPopoverIfRequested("spotify") { showsPlayer = true } }
    }

    private func control(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13 * metrics.unit))
                .frame(width: 24 * metrics.unit, height: 32 * metrics.unit)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SpotifyArtwork: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable()
        } placeholder: {
            Image(systemName: "music.note")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.11, green: 0.73, blue: 0.33))  // Spotify green
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size / 6, style: .continuous))
    }
}

/// Fast User Switching: the Mac's other accounts; click one to switch to it.
private struct UsersWidget: View {
    @ObservedObject private var users = MacUsers.shared
    @Environment(\.dockMetrics) private var metrics

    var body: some View {
        let u = metrics.unit
        let stack = metrics.axis == .vertical
            ? AnyLayout(VStackLayout(spacing: 6 * u))
            : AnyLayout(HStackLayout(spacing: 6 * u))
        stack {
            ForEach(users.others) { user in
                Button { UserSwitching.switchTo(user) } label: {
                    UserAvatar(user: user, size: 34 * u)
                }
                .buttonStyle(.plain)
                .help("Switch to \(user.fullName)")
            }
            if users.others.isEmpty {
                Button { UserSwitching.showLoginWindow() } label: {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 14 * u))
                        .frame(width: 34 * u, height: 34 * u)
                        .background(.quaternary, in: Circle())
                }
                .buttonStyle(.plain)
                .help("Switch User…")
            }
        }
        .padding(metrics.axis == .vertical ? .vertical : .horizontal, 7 * u)
        .frame(
            width: metrics.axis == .vertical ? metrics.iconSize : nil,
            height: metrics.axis == .vertical ? nil : metrics.iconSize)
        .widgetTile()
    }
}

private struct UserAvatar: View {
    let user: MacUser
    let size: CGFloat

    var body: some View {
        Group {
            if let path = user.picturePath, let picture = NSImage(contentsOfFile: path) {
                Image(nsImage: picture).resizable().scaledToFill()
            } else {
                // Like macOS's own avatars for accounts without a picture.
                Text(user.initials)
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.gradient)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
