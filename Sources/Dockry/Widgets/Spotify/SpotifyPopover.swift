import AppKit
import DockryCore
import SwiftUI

/// The player that opens from the Spotify widget: the song with its progress, playback
/// controls and volume, and search, without bringing Spotify to the front.
struct SpotifyPopover: View {
    @ObservedObject var player: SpotifyPlayer
    @ObservedObject private var account = SpotifyAccount.shared

    @State private var query = ScreenshotHook.spotifySearchQuery ?? ""
    /// Search stays tucked away until asked for, so the player is just the player.
    @State private var showsSearch = ScreenshotHook.spotifySearchQuery != nil
    @FocusState private var searchFieldFocused: Bool
    @State private var results: [SpotifySearchResult] = []
    @State private var searchError: String?
    @State private var scrubPosition: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            nowPlaying
            if let playback = player.playback {
                progress(playback)
            }
            controls
            if let playback = player.playback {
                volume(playback)
            }
            if showsSearch {
                Divider()
                search
            }
        }
        .padding(16)
        .frame(width: 320)
        .animation(.easeOut(duration: 0.2), value: showsSearch)
        .onAppear { player.startFollowingPlayback() }
        .onDisappear { player.stopFollowingPlayback() }
        .task(id: query) { await runSearch() }
    }

    private var nowPlaying: some View {
        HStack(alignment: .top, spacing: 12) {
            SpotifyArtwork(url: player.track?.artworkURL, size: 64)
            VStack(alignment: .leading, spacing: 2) {
                Text(player.track?.title ?? "Nothing playing")
                    .font(.headline)
                Text(player.track?.artist ?? "Press play, or search for a song.")
                    .foregroundStyle(.secondary)
            }
            .lineLimit(2)
            Spacer(minLength: 0)
            Button {
                showsSearch.toggle()
                searchFieldFocused = showsSearch
            } label: {
                Image(systemName: showsSearch ? "xmark.circle.fill" : "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(showsSearch ? "Hide search" : "Search Spotify")
        }
    }

    private func progress(_ playback: SpotifyPlayback) -> some View {
        VStack(spacing: 2) {
            Slider(
                value: Binding(get: { scrubPosition ?? playback.position }, set: { scrubPosition = $0 }),
                in: 0...max(playback.duration, 1),
                onEditingChanged: { isEditing in
                    if !isEditing, let scrubPosition {
                        player.seek(to: scrubPosition)
                        self.scrubPosition = nil
                    }
                })
            .controlSize(.small)
            HStack {
                Text(Self.time(scrubPosition ?? playback.position))
                Spacer()
                Text(Self.time(playback.duration))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        HStack(spacing: 18) {
            toggle("shuffle", isOn: player.playback?.isShuffling == true, help: "Shuffle") { player.toggleShuffle() }
            button("backward.fill", size: 16, help: "Previous") { player.previous() }
            button(player.track?.isPlaying == true ? "pause.circle.fill" : "play.circle.fill", size: 34, help: "Play or pause") {
                player.playPause()
            }
            button("forward.fill", size: 16, help: "Next") { player.next() }
            toggle("repeat", isOn: player.playback?.isRepeating == true, help: "Repeat") { player.toggleRepeat() }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }

    private func volume(_ playback: SpotifyPlayback) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.fill").foregroundStyle(.secondary)
            Slider(
                value: Binding(get: { Double(playback.volume) }, set: { player.setVolume(Int($0)) }),
                in: 0...100)
                .controlSize(.small)
            Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    @ViewBuilder private var search: some View {
        TextField("Search Spotify", text: $query)
            .textFieldStyle(.roundedBorder)
            .focused($searchFieldFocused)
        if !account.canSearch {
            VStack(alignment: .leading, spacing: 6) {
                Text("Connect your Spotify account in Dockry’s settings to search here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Open Settings…") { SettingsWindow.show(widget: .spotify) }
                    if !query.isEmpty, let url = Self.spotifySearchURL(query) {
                        Button("Search in Spotify") { NSWorkspace.shared.open(url) }
                    }
                }
                .controlSize(.small)
            }
        } else if let searchError {
            Text(searchError).font(.caption).foregroundStyle(.secondary)
        } else if results.isEmpty {
            if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("Searching…").font(.caption).foregroundStyle(.secondary)
            }
        } else {
            // As tall as the results, up to a limit; then it scrolls. (A scroll view on its
            // own has no height of its own to give the popover, so set one.)
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(results) { result in
                        SearchResultRow(result: result) { player.play(uri: result.uri) }
                    }
                }
            }
            .frame(height: min(CGFloat(results.count) * SearchResultRow.height, Self.maxResultsHeight))
        }
    }

    private static let maxResultsHeight: CGFloat = 240

    private func runSearch() async {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard account.canSearch, !query.isEmpty else {
            results = []
            searchError = nil
            return
        }
        // Wait for a pause in typing; a new keystroke cancels this task.
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }
        do {
            results = try await account.search(query)
            searchError = results.isEmpty ? "No songs found." : nil
        } catch is CancellationError {
        } catch {
            if !Task.isCancelled {
                searchError = error.localizedDescription
            }
        }
    }

    private func button(_ symbol: String, size: CGFloat, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: size))
        }
        .help(help)
    }

    private func toggle(_ symbol: String, isOn: Bool, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isOn ? Color(red: 0.11, green: 0.73, blue: 0.33) : .secondary)
        }
        .help(help)
        .disabled(player.playback == nil)
    }

    private static func time(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private static func spotifySearchURL(_ query: String) -> URL? {
        query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed).flatMap { URL(string: "spotify:search:\($0)") }
    }
}

private struct SearchResultRow: View {
    /// Row height plus the spacing between rows.
    static let height: CGFloat = 50

    let result: SpotifySearchResult
    let play: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: play) {
            HStack(spacing: 10) {
                SpotifyArtwork(url: result.artworkURL, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(result.title).font(.system(size: 12, weight: .semibold))
                    Text("\(result.artist) · \(result.album)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "play.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(6)
            .frame(height: Self.height - 2)
            .background(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Play in Spotify")
    }
}
