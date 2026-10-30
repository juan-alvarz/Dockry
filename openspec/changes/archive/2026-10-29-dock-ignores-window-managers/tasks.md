# Tasks

## 1. Dock panel

- [x] 1.1 Refuse and ignore Accessibility frame, position, size, minimize, full-screen, main and focus setters in `DockPanel`, and verify `swift build`
- [x] 1.2 Remember the frame `place(on:…)` sets and restore it when the panel moves or resizes, and verify `swift build`
- [x] 1.3 Verify with an Accessibility script that setting the dock window's position leaves it in place, or record why it couldn't be run here

Note on 1.3: not run here. The shell running the implementation has no Accessibility
access (`AXIsProcessTrusted()` is false), and the installed Dockry in /Applications was
running, so a second instance wasn't started. To check by hand: install this build,
open a dock popover, press Rectangle's maximize shortcut, and confirm the dock stays.
