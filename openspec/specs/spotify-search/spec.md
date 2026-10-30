# spotify-search Specification

## Purpose

Search for songs from the Spotify player and play them in the Spotify app. Search uses the Spotify Web API, which needs a one-time setup with the user's own client ID and a sign-in.

## Requirements

### Requirement: One-time setup
Settings › Widgets › Spotify SHALL explain creating an app on the Spotify Developer Dashboard, show the redirect URI `dockry://spotify-callback` with a Copy button, take the app's client ID and offer Sign In… (disabled without a client ID) or Sign Out, with the current status.

#### Scenario: No client ID
- **WHEN** the client ID field is empty
- **THEN** Sign In… is disabled

### Requirement: Sign-in with PKCE
Sign In… SHALL open Spotify's authorization page in the browser using PKCE (no client secret) and a random state, asking for no scopes. The callback SHALL be accepted only if its state matches; then Dockry exchanges the code for tokens and comes back to the front.

#### Scenario: Wrong state
- **WHEN** a `dockry://spotify-callback` arrives with a state Dockry didn't send
- **THEN** sign-in fails with a message and no token is stored

### Requirement: Keeping the sign-in
The refresh token SHALL be saved in `~/Library/Application Support/Dockry/spotify-refresh-token`, readable only by the user, not in the Keychain. Access tokens SHALL be refreshed a minute before they expire. A refresh token Spotify rejects SHALL sign the user out.

#### Scenario: Revoked access
- **WHEN** the user removes the app's access on Spotify's site and then searches
- **THEN** Dockry signs out and says to sign in again in Settings

### Requirement: Searching
The player's search field SHALL search tracks after a short pause in typing (about 0.35 seconds), show up to eight results with art, title, artists and album, and say when nothing is found. A rejected access token SHALL be renewed and the search tried once more.

#### Scenario: Type a query
- **WHEN** the user types a song name and pauses
- **THEN** matching songs are listed

### Requirement: Playing a result
Clicking a result SHALL play it in the Spotify app through AppleScript, which doesn't need Premium, keeping Spotify in the background.

#### Scenario: Play a result
- **WHEN** the user clicks a search result
- **THEN** Spotify plays that song and stays in the background

### Requirement: Without a sign-in
Without a sign-in the player SHALL explain that search needs the account connected, link to Settings, and offer Search in Spotify, which opens the query in the Spotify app.

#### Scenario: Not signed in
- **WHEN** the user types in the search field without signing in
- **THEN** Search in Spotify opens the Spotify app's search for that text
