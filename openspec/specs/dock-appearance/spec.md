# dock-appearance Specification

## Purpose

How the dock looks and behaves on screen, matching the macOS Dock's own options: position, size, magnification, automatic hiding, indicators and launch animation, which screens get a dock, and following the macOS Dock's settings.

## Requirements

### Requirement: A floating dock on every desktop
The dock SHALL float at the macOS Dock's window level on every desktop, including next to full-screen apps, and SHALL never take keyboard focus from the app in use. Clicks on its transparent surroundings SHALL go to the windows below, and the first click on an icon SHALL act at once.

#### Scenario: Click an icon from another app
- **WHEN** the user is typing in an app and clicks an icon in the dock
- **THEN** the icon's action happens on that first click

### Requirement: Position and screens
The dock SHALL sit at the bottom, left or right edge. At the bottom every screen SHALL get a dock; on a side, only the screen at that far edge of the display arrangement (the main screen on a tie). Docks SHALL follow screens being added, removed or rearranged.

#### Scenario: Two screens, left dock
- **WHEN** the built-in display is left of an external one and the dock is on the left
- **THEN** only the built-in display has a dock

#### Scenario: Bottom with two screens
- **WHEN** the dock is at the bottom with two screens
- **THEN** each screen has its own dock

### Requirement: Size and length
Icon size SHALL be between 16 and 128 points (48 by default), and widgets SHALL scale with it. The dock SHALL be as long as its items and centered on its edge; when that would be longer than the screen it SHALL scroll instead, without magnification, its ends faded.

#### Scenario: Too many items
- **WHEN** the items don't fit along the screen edge
- **THEN** the dock fills the edge and scrolls

### Requirement: Resize by dragging a divider
Dragging any divider across the dock (toward or away from the middle of the screen) SHALL change the icon size, with the resize cursor shown over dividers and during the drag, unless the dock follows the macOS Dock's settings.

#### Scenario: Grow the dock
- **WHEN** the user drags a divider of a bottom dock upward by 20 points
- **THEN** the icon size grows by 20 points, within 16 to 128

### Requirement: Magnification
With magnification on, app and folder icons near the pointer SHALL grow smoothly, the one under it to the magnified size, while the spot under the pointer stays put and the dock's own frame doesn't move. Magnification SHALL ease in and out, and SHALL pause while something is being dragged.

#### Scenario: Pointer over an icon
- **WHEN** magnification is on with 48-point icons and an 80-point magnified size
- **THEN** the icon under the pointer is drawn at 80 points and its neighbors smaller

### Requirement: Automatic hiding
With automatic hiding on, the dock SHALL slide off its edge and reappear when the pointer reaches that edge within the dock's span. It SHALL linger about 0.4 seconds after the pointer leaves, and SHALL stay shown while one of its popovers is open, an item is dragged or it's being resized.

#### Scenario: Popover keeps it up
- **WHEN** the calendar popover is open and the pointer leaves the dock
- **THEN** the dock stays shown until the popover closes

### Requirement: Indicators and launch animation
Running-app dots SHALL show only when indicators are on. With launch animation on, clicking an app that isn't running SHALL bounce it until it runs, at most six times.

#### Scenario: Launch bounce
- **WHEN** the user clicks an app that isn't running
- **THEN** it bounces until it's running

### Requirement: Room for the macOS Dock
While the macOS Dock is showing, the dock SHALL stay within the area the macOS Dock leaves free. While Dockry hides the macOS Dock, the dock SHALL use that space too.

#### Scenario: Both docks at the bottom
- **WHEN** the macOS Dock is visible at the bottom
- **THEN** Dockry's dock sits just above it

### Requirement: Sync with Mac Dock settings
With "Sync with Mac Dock settings" on, the dock SHALL use the macOS Dock's size, magnification and magnified size, position, hiding, indicators and launch animation instead of Dockry's own, follow changes within a couple of seconds, and disable editing those settings in Dockry.

#### Scenario: Change the Mac Dock's size
- **WHEN** syncing is on and the user changes the Dock size in System Settings
- **THEN** Dockry's dock changes size within a few seconds

#### Scenario: Dockry hides the macOS Dock while syncing
- **WHEN** Dockry is hiding the macOS Dock and syncing is on
- **THEN** the dock uses the user's own hiding setting, not the one Dockry set to hide the Dock

### Requirement: Dock background menu
Right-clicking the dock's background SHALL offer turning magnification on or off, turning hiding on or off, the position, and Dock Settings…, plus adding a divider, folder or widget at the end. While syncing, it SHALL say it follows the macOS Dock's settings instead of offering those toggles.

#### Scenario: Move the dock from its menu
- **WHEN** the user right-clicks the background and chooses Position on Screen › Left
- **THEN** the dock moves to the left edge
