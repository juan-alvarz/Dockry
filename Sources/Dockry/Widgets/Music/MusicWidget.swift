import AppKit
import DockryCore
import SwiftUI

/// Now playing in the Music app, with previous / play-pause / next, like the Spotify widget.
/// Clicking the song opens the player, with a search of the library. In a dock on the side
/// of the screen it's the album art above the controls.
struct MusicWidget: View {
    static let widget = DockWidget(info: WidgetKind.music.info) { AnyView(MusicWidget()) }

    /// Music's red, behind the note while there's no album art.
    static let red = Color(red: 0.98, green: 0.18, blue: 0.28)

    // Owned by the widget, so Music is only watched (and asked for permission) while a
    // profile with this widget is showing.
    @StateObject private var player = MusicPlayer()
    @Environment(\.dockMetrics) private var metrics
    @State private var showsPlayer = false

    var body: some View {
        let u = metrics.unit
        Group {
            if metrics.axis == .vertical {
                VStack(spacing: 2 * u) {
                    Button { showsPlayer.toggle() } label: {
                        SpotifyArtwork(url: player.artworkURL, size: metrics.iconSize - 10 * u, placeholder: Self.red)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(player.track.map { "\($0.title) — \($0.artist)" } ?? "Apple Music")
                    control("backward.fill", height: 22) { player.previous() }
                    control(player.track?.isPlaying == true ? "pause.fill" : "play.fill", height: 22) { player.playPause() }
                    control("forward.fill", height: 22) { player.next() }
                }
                .padding(.vertical, 5 * u)
                .frame(width: metrics.iconSize)
                .widgetTile()
            } else {
                HStack(spacing: 8 * u) {
                    Button { showsPlayer.toggle() } label: {
                        HStack(spacing: 8 * u) {
                            SpotifyArtwork(url: player.artworkURL, size: 36 * u, placeholder: Self.red)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(player.track?.title ?? "Apple Music")
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
        .dockPopover(isPresented: $showsPlayer) { MusicPopover(player: player) }
        .onAppear { ScreenshotHook.openPopoverIfRequested("music") { showsPlayer = true } }
    }

    private func control(_ symbol: String, height: CGFloat = 32, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13 * metrics.unit))
                .frame(width: 24 * metrics.unit, height: height * metrics.unit)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
