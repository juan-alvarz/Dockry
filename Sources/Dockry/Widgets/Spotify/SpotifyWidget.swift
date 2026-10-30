import AppKit
import DockryCore
import SwiftUI

/// Now playing in Spotify, with previous / play-pause / next. Clicking the song opens the
/// player, with search. In a dock on the side of the screen it's the album art above the
/// controls.
struct SpotifyWidget: View {
    static let widget = DockWidget(
        info: WidgetKind.spotify.info,
        makeView: { AnyView(SpotifyWidget()) },
        makeSettings: { AnyView(SpotifySettings()) })

    // Owned by the widget, so Spotify is only watched (and asked for permission) while a
    // profile with this widget is showing.
    @StateObject private var player = SpotifyPlayer()
    @Environment(\.dockMetrics) private var metrics
    @State private var showsPlayer = false

    var body: some View {
        let u = metrics.unit
        Group {
            if metrics.axis == .vertical {
                // A tall tile: the album art (click for the player), then the controls.
                VStack(spacing: 2 * u) {
                    Button { showsPlayer.toggle() } label: {
                        SpotifyArtwork(url: player.track?.artworkURL, size: metrics.iconSize - 10 * u)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(player.track.map { "\($0.title) — \($0.artist)" } ?? "Spotify")
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

/// Album art, or a Spotify-green note while there's none.
///
/// Not AsyncImage: that gives up for good when its load is cancelled, which happens when
/// the dock rebuilds the tile (a side dock does it often), leaving the note instead of the
/// art. `task(id:)` starts over whenever the tile comes back, and the cache makes that free.
struct SpotifyArtwork: View {
    let url: URL?
    let size: CGFloat
    /// Behind the note while there's no art.
    var placeholder = Color(red: 0.11, green: 0.73, blue: 0.33)  // Spotify green
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(placeholder)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size / 6, style: .continuous))
        .task(id: url) {
            guard let url else {
                image = nil
                return
            }
            let loaded = await ArtworkCache.load(url)
            if !Task.isCancelled {
                image = loaded
            }
        }
    }
}

/// Album art by URL, shared by every Spotify widget (there's one per screen), the player
/// and the search results.
@MainActor
enum ArtworkCache {
    private static let images = NSCache<NSURL, NSImage>()

    /// The image at `url` (Spotify's servers, or a file for CI's screenshots), or nil if it
    /// couldn't be loaded.
    static func load(_ url: URL) async -> NSImage? {
        if let cached = images.object(forKey: url as NSURL) {
            return cached
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = NSImage(data: data)
        else { return nil }
        images.setObject(image, forKey: url as NSURL)
        return image
    }
}
