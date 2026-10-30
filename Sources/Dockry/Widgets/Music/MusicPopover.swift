import AppKit
import DockryCore
import SwiftUI

/// The player that opens from the Apple Music widget: the song with its progress, controls
/// and volume, and a search of the library, without bringing Music to the front.
struct MusicPopover: View {
    @ObservedObject var player: MusicPlayer

    @State private var query = ""
    /// Search stays tucked away until asked for, so the player is just the player.
    @State private var showsSearch = false
    @FocusState private var searchFieldFocused: Bool
    @State private var results: [MusicSearchResult] = []
    @State private var searchMessage: String?
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
            Button("Open Music") { player.openApp() }
                .buttonStyle(.link)
                .font(.caption)
                .frame(maxWidth: .infinity)
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
            SpotifyArtwork(url: player.artworkURL, size: 64, placeholder: MusicWidget.red)
            VStack(alignment: .leading, spacing: 2) {
                Text(player.track?.title ?? "Nothing playing")
                    .font(.headline)
                Text(player.track.map { [$0.artist, $0.album].filter { !$0.isEmpty }.joined(separator: " · ") } ?? "Press play, or search your library.")
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
            .help(showsSearch ? "Hide search" : "Search your library")
        }
    }

    private func progress(_ playback: MusicPlayback) -> some View {
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
        let repeatMode = player.playback?.repeatMode ?? .off
        return HStack(spacing: 18) {
            toggle("shuffle", isOn: player.playback?.isShuffling == true, help: "Shuffle") { player.toggleShuffle() }
            button("backward.fill", size: 16, help: "Previous") { player.previous() }
            button(player.track?.isPlaying == true ? "pause.circle.fill" : "play.circle.fill", size: 34, help: "Play or pause") {
                player.playPause()
            }
            button("forward.fill", size: 16, help: "Next") { player.next() }
            toggle(repeatMode == .one ? "repeat.1" : "repeat", isOn: repeatMode != .off, help: "Repeat: \(repeatMode.rawValue)") {
                player.cycleRepeat()
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }

    private func volume(_ playback: MusicPlayback) -> some View {
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
        TextField("Search your library", text: $query)
            .textFieldStyle(.roundedBorder)
            .focused($searchFieldFocused)
        if let searchMessage {
            Text(searchMessage).font(.caption).foregroundStyle(.secondary)
        } else if !results.isEmpty {
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(results) { result in
                        MusicResultRow(result: result) { player.play(result) }
                    }
                }
            }
            .frame(height: min(CGFloat(results.count) * MusicResultRow.height, 240))
        }
    }

    private func runSearch() async {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            results = []
            searchMessage = nil
            return
        }
        // Wait for a pause in typing; a new keystroke cancels this task.
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }
        searchMessage = "Searching…"
        let found = await player.search(query)
        guard !Task.isCancelled else { return }
        results = found
        searchMessage = found.isEmpty ? "No songs found in your library." : nil
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
                .foregroundStyle(isOn ? MusicWidget.red : .secondary)
        }
        .help(help)
        .disabled(player.playback == nil)
    }

    private static func time(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct MusicResultRow: View {
    /// Row height plus the spacing between rows.
    static let height: CGFloat = 40

    let result: MusicSearchResult
    let play: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: play) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(result.title).font(.system(size: 12, weight: .semibold))
                    Text([result.artist, result.album].filter { !$0.isEmpty }.joined(separator: " · "))
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
        .help("Play in Music")
    }
}
