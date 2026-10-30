# Spec Delta

## Purpose

The Trash in the dock, like the macOS Dock's: shows whether the Trash has anything in it, takes files dropped on it, and opens or empties the Trash.

## ADDED Requirements

### Requirement: Empty or full
The Trash widget SHALL show the system's empty Trash icon when the Trash holds nothing (a Finder `.DS_Store` doesn't count) and the full icon otherwise, updating within a few seconds of the Trash changing while the widget is on screen. It SHALL do so without Full Disk Access.

#### Scenario: Something moved to the Trash
- **WHEN** the Trash was empty and the user deletes a file in Finder
- **THEN** the widget shows the full Trash within a few seconds

### Requirement: Drop to delete
Dropping files or folders from Finder onto the Trash widget SHALL move them to the Trash, where they can be put back, instead of adding them to the dock. While a drag is over it, the widget SHALL be highlighted and the dock SHALL open no gap.

#### Scenario: Drop a file
- **WHEN** the user drags a document from Finder onto the Trash widget and lets go
- **THEN** the document is in the Trash and the dock is unchanged

### Requirement: Open and empty
Clicking the widget SHALL open the Trash in Finder. Its right-click menu SHALL offer Open and Empty Trash…, disabled while the Trash is empty. Empty Trash… SHALL ask for confirmation, saying it can't be undone, and only then have Finder empty the Trash; if Dockry isn't allowed to control Finder, it SHALL say how to allow it.

#### Scenario: Cancel emptying
- **WHEN** the user chooses Empty Trash… and then Cancel
- **THEN** nothing is deleted

#### Scenario: Empty
- **WHEN** the user chooses Empty Trash… and confirms
- **THEN** Finder empties the Trash and the widget shows the empty icon
