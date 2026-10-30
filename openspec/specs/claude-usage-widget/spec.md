# claude-usage-widget Specification

## Purpose

Shows how much of the Claude plan's 5-hour and weekly limits are used, the same numbers as `/usage` in Claude Code, using the account Claude Code is signed in to. The endpoint is unofficial and rate-limits hard, so the widget asks rarely and never breaks Claude Code's own sign-in.

## Requirements

### Requirement: Uses Claude Code's sign-in
The widget SHALL read Claude Code's saved sign-in from its "Claude Code-credentials" Keychain item, off the main thread; the first read makes macOS ask for permission. If the user denies it, Dockry SHALL not ask again until it restarts.

#### Scenario: Permission denied
- **WHEN** the user clicks Deny on the Keychain prompt
- **THEN** the widget shows access denied and no further prompt appears until Dockry restarts

#### Scenario: Not signed in
- **WHEN** there's no Claude Code sign-in in the Keychain
- **THEN** the widget says to sign in to Claude Code

### Requirement: How often it asks
While a widget is on screen, Dockry SHALL fetch usage every 5 minutes; after a rate-limit answer it SHALL wait 30 minutes. A manual refresh (the popover's refresh button, or opening the popover) SHALL be ignored if the last attempt was under a minute ago.

#### Scenario: Rate limited
- **WHEN** the usage endpoint answers 429
- **THEN** the next request is 30 minutes later and the last numbers stay on screen

### Requirement: Renewing an expired sign-in
When the saved sign-in has expired (or expires within a minute), Dockry SHALL renew it as Claude Code does and save the new tokens back into the same Keychain item, keeping everything else in it. It SHALL first check that it can write that item and SHALL not renew if it can't, so Claude Code never loses a single-use refresh token.

#### Scenario: Can't write the item
- **WHEN** the sign-in has expired and Dockry isn't allowed to update the Keychain item
- **THEN** Dockry doesn't renew it and the widget says to open Claude Code

#### Scenario: Renewed
- **WHEN** the sign-in has expired and Dockry can write the item
- **THEN** the new sign-in is saved for Claude Code too, and the usage loads

### Requirement: Failures keep the last numbers
Being offline, an unexpected answer or a rate limit SHALL keep the last numbers on screen; only with none yet SHALL the widget show unavailable. A 401 SHALL show that the sign-in expired.

#### Scenario: Goes offline
- **WHEN** the Mac goes offline after usage loaded
- **THEN** the widget keeps showing the last percentages

### Requirement: Widget and popover
On a bottom dock the widget SHALL show a bar and percentage for the 5-hour and weekly limits, turning red from 90%, or a short status. On a side dock it SHALL show Claude's icon with the 5-hour percentage on a badge ("!" without numbers). Clicking SHALL open each limit with its percentage, bar and reset time, when it last updated, a refresh button and a link to claude.ai's usage page.

#### Scenario: Near the limit
- **WHEN** 92% of the 5-hour limit is used
- **THEN** its bar is red
