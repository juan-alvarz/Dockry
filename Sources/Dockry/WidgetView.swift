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
        }
    }
}

private struct ClockWidget: View {
    let date: Date

    var body: some View {
        Text(date, format: .dateTime.hour().minute())
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .padding(.horizontal, 10)
            .frame(minWidth: 72, minHeight: 48)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// A calendar-style tile: month on top, day of the month below.
private struct DateWidget: View {
    let date: Date

    var body: some View {
        VStack(spacing: 0) {
            Text(date, format: .dateTime.month(.abbreviated))
                .textCase(.uppercase)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.red)
            Text(date, format: .dateTime.day())
                .font(.system(size: 22, weight: .medium, design: .rounded))
        }
        .frame(width: 48, height: 48)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Now playing in Spotify, with previous / play-pause / next.
private struct SpotifyWidget: View {
    // Owned by the widget, so Spotify is only watched (and asked for permission) while a
    // profile with this widget is showing.
    @StateObject private var player = SpotifyPlayer()

    var body: some View {
        HStack(spacing: 8) {
            artwork
            VStack(alignment: .leading, spacing: 1) {
                Text(player.track?.title ?? "Spotify")
                    .font(.system(size: 12, weight: .semibold))
                Text(player.track?.artist ?? "Not playing")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .frame(width: 112, alignment: .leading)
            HStack(spacing: 0) {
                control("backward.fill") { player.previous() }
                control(player.track?.isPlaying == true ? "pause.fill" : "play.fill") { player.playPause() }
                control("forward.fill") { player.next() }
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 48)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var artwork: some View {
        AsyncImage(url: player.track?.artworkURL) { image in
            image.resizable()
        } placeholder: {
            Image(systemName: "music.note")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.11, green: 0.73, blue: 0.33))  // Spotify green
        }
        .frame(width: 36, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func control(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .frame(width: 24, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
