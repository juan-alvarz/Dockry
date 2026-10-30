# Proposal

## Why

GitHub release pages turn every line break in the notes into a hard break, and
CHANGELOG.md wraps its lines at about 95 columns, so released notes break mid-sentence
("…for your town / from Location Services…"). The notes are also a flat list with the
install text appended as two loose paragraphs, unlike the clearer releases of Shortty.

## What Changes

- The release notes join wrapped lines back into whole paragraphs and bullets, so
  CHANGELOG.md keeps its wrapped lines in the code and the release reads cleanly.
- A version's section can use `###` subsections (What's new, Fixes, Updating from …) and
  bold lead-ins, and they come through to the release.
- The Release workflow ends the notes with an **Install** section of numbered steps and the
  requirements, instead of two loose paragraphs.
- CHANGELOG.md's Unreleased section becomes 0.2.0 in that style.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `build-and-release`: adds a requirement for how release notes are formatted.

## Impact

- `scripts/version.sh` (`--notes` unwraps), `.github/workflows/release.yml` (Install
  section), `CHANGELOG.md` (0.2.0, and its header explains the format).
- The app's version still comes from the first version heading; nothing in the app changes.
