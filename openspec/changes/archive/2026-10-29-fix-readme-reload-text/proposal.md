# Proposal

## Why

The README tells users to choose **Reload Profiles** after fixing a broken profiles.json.
No such item exists; the menu's warning opens Settings › Profiles, which has **Reload
from File** (finding 6).

## What Changes

- README's "Profiles file" section names Reload from File in Settings › Profiles.
- The missing `docs/screenshots/12-settings-widgets.png` is produced by
  `scripts/screenshots.sh`; it appears after the next Build & Screenshots run on `dev`, so
  nothing changes for it here.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. Documentation only (`skip_specs`).

## Impact

- `README.md`.
