# fast-user-switching Specification

## Purpose

Switches to another account on the Mac, as the user menu in Control Center does, from the Switch User widget or the menu bar menu. macOS has no public API for this, so Dockry uses the private function behind Fast User Switching and falls back to the login window.

## Requirements

### Requirement: Which accounts are listed
Dockry SHALL list the Mac's people accounts other than the current one, sorted by full name, leaving out system accounts: user IDs below 501, hidden accounts and names starting with an underscore.

#### Scenario: System accounts
- **WHEN** the Mac has `_spotlight`, a hidden admin and two people
- **THEN** only the person who isn't signed in to this session is listed

### Requirement: Switching to an account
Choosing an account SHALL switch to it as Fast User Switching does. If the system function is missing or fails, Dockry SHALL open the login window instead.

#### Scenario: Function removed in a future macOS
- **WHEN** the switching function isn't available
- **THEN** choosing an account opens the login window, which lists every account

### Requirement: Users widget
The widget SHALL show each other account's picture, or its initials (up to two) on a gray circle, with a tooltip naming it; clicking one switches to it. With no other accounts it SHALL show a single button that opens the login window. On a side dock the avatars stack vertically.

#### Scenario: Account without a picture
- **WHEN** an account named Alex Rivera has no picture
- **THEN** its avatar shows AR

### Requirement: Menu bar entry
The menu bar menu's Switch User SHALL list the same accounts, then Login Window…

#### Scenario: Open the login window
- **WHEN** the user chooses Switch User › Login Window…
- **THEN** the login window appears and the session stays logged in

### Requirement: Needs Fast User Switching
Switching SHALL need Fast User Switching to be turned on in System Settings; the widget's description SHALL say so.

#### Scenario: Widget needs
- **WHEN** the user views Switch User in Settings › Widgets
- **THEN** it lists Fast User Switching as required
