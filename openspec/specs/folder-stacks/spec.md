# folder-stacks Specification

## Purpose

Folders in the dock work like the macOS Dock's stacks: the folder's icon, and a click shows what's inside, newest first, with folders opening in place.

## Requirements

### Requirement: Adding folders
A folder SHALL be added to the active profile by dropping it from Finder onto the dock, or with Add Folder… from any right-click menu in the dock, which asks for a folder starting in Downloads and adds it right after the item clicked.

#### Scenario: Add Downloads
- **WHEN** the user chooses Add Folder… on the dock's background and picks Downloads
- **THEN** a Downloads stack is added at the end of the dock

### Requirement: Opening a stack
Clicking a folder SHALL open a grid of its contents without hidden files, sorted by date added (or created) with the newest first. An empty folder SHALL say so.

#### Scenario: New download
- **WHEN** a file was just downloaded and the user clicks the Downloads stack
- **THEN** the file is first in the grid

### Requirement: Inside the stack
Clicking a folder in the grid SHALL open it in place with a Back button; apps and packages count as files. Clicking a file SHALL open it in its app and close the stack. Each entry SHALL offer Show in Finder, and the stack SHALL offer Open in Finder for the folder being shown.

#### Scenario: Open a subfolder
- **WHEN** the user clicks a folder inside the stack
- **THEN** the stack shows that folder's contents, and Back returns to the parent

### Requirement: Folder item menu
A folder's right-click menu SHALL offer Remove from <profile> and Open in Finder.

#### Scenario: Remove a folder
- **WHEN** the user chooses Remove from Work on a folder
- **THEN** the folder leaves Work's dock and stays on disk
