# Changelog notes

Critical changes only: behavior users notice, saved data and settings formats, and
architecture moves. Newest first. User-facing release notes are in CHANGELOG.md.

- **2026-11-12** Profile windows after a code review: an app that can't open a window in
  the profile has its front window brought there; parked windows are checked on every
  switch and when the desktop or screens change; profiles.json edited by hand is read
  before Dockry's next change instead of being saved over. New in DockryCore:
  `WindowParking`, `ProfileAppRules.focusAfterSwitch`. Saved formats unchanged.
- **2026-11-03** OpenSpec removed (`openspec/`, `.claude/commands/opsx`,
  `.claude/skills/openspec-*`); project memory lives in `docs/memory/`, rules in AGENTS.md.
- **2026-11-02 (0.3.0)** One setting, "Give each profile its own windows", on by default;
  windows are parked per profile and apps are never hidden. `opensNewAppInstances`,
  `ownWallpapers`, `wallpapersSetByDockry` and `appProfiles` are deleted at launch.
- **2026-11-02 (0.3.0)** `profileWindows` keeps its saved format (`[String: Record]`, window
  number → profile, pid, parked frame). New one-time flag `wallpapersGivenToProfiles`;
  a profile's "None" wallpaper now means the macOS default picture.
- **2026-11-02 (0.3.0)** Rules moved to DockryCore: `ProfileWindowRecords`, `ProfileAppRules`.
- **2026-10-29 (0.2.0)** First launch makes one Default profile (Finder) instead of Work and Chill.
- **2026-10-29 (0.2.0)** `weatherTemperatureUnit` is `celsius` or `fahrenheit`; a saved
  `system` reads as Celsius.
- **2026-10-29 (0.2.0)** profiles.json gains widget names `music` and `trash`.
- **2026-10-29** `appOwners` (pid + launch time → profile) replaces `appProfiles`.
- **2026-10-29** Bundle id `com.dockry.Dockry` (`io.github.juan-alvarz.Dockry` up to 0.0.7);
  the old defaults domain is copied on first launch.
