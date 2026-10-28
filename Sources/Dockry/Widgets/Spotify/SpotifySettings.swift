import AppKit
import DockryCore
import SwiftUI

/// Spotify's part of Settings › Widgets: the account the player searches with.
struct SpotifySettings: View {
    @ObservedObject private var account = SpotifyAccount.shared

    var body: some View {
        Group {
            Section("Search") {
                Text("Searching from the Spotify widget uses your Spotify account. Spotify asks every app for its own client ID, so set one up once:")
                VStack(alignment: .leading, spacing: 6) {
                    Text("1. Open the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard) and create an app. Any name works.")
                    Text("2. Under Redirect URIs, add the one below. Under APIs, choose Web API.")
                    Text("3. Copy the app’s Client ID into the field below and click Sign In.")
                }
                .font(.callout)
                LabeledContent("Redirect URI") {
                    HStack {
                        Text(SpotifyWebAPI.redirectURI)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(SpotifyWebAPI.redirectURI, forType: .string)
                        }
                    }
                }
                TextField("Client ID", text: $account.clientID)
            }

            Section {
                HStack {
                    statusLabel
                    Spacer()
                    if account.status == .signedIn {
                        Button("Sign Out") { account.signOut() }
                    } else {
                        Button("Sign In…") { account.signIn() }
                            .disabled(account.clientID.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                Text("Songs you pick play in the Spotify app, which stays in the background. Playing doesn’t need Premium.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var statusLabel: some View {
        switch account.status {
        case .signedOut: Label("Not signed in", systemImage: "person.crop.circle.badge.xmark")
        case .signingIn: Label("Finish signing in in your browser…", systemImage: "safari")
        case .signedIn: Label("Signed in", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed(let message): Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
    }
}
