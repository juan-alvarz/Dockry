# Spec Delta

## MODIFIED Requirements

### Requirement: Dock background menu
Right-clicking the dock's background SHALL offer turning magnification on or off, turning hiding on or off, the position, and Dock Settings…, plus adding a divider, folder or widget at the spot that was clicked: in front of the first item past the click along the dock, or at the end past the last item. While syncing, it SHALL say it follows the macOS Dock's settings instead of offering those toggles.

#### Scenario: Move the dock from its menu
- **WHEN** the user right-clicks the background and chooses Position on Screen › Left
- **THEN** the dock moves to the left edge

#### Scenario: Add a divider between two apps
- **WHEN** the user right-clicks the background in the gap between Zed (pinned) and the open apps after it and chooses Add Divider
- **THEN** the divider appears in that gap
