# Tasks

## 1. Notes

- [x] 1.1 Make `scripts/version.sh --notes` join wrapped lines, and verify its output for 0.1.1 has each bullet on one line and `scripts/version.sh` still prints the version
- [x] 1.2 Turn the release workflow's closing paragraphs into an Install section, and verify the YAML still parses
- [x] 1.3 Rewrite Unreleased as 0.2.0 with What's new, Fixes and Updating from 0.1.1, explain the format in the CHANGELOG header, and verify `scripts/version.sh` prints 0.2.0

## 2. Check

- [x] 2.1 Render the final notes (script output plus the workflow's Install section) with GitHub's Markdown renderer and confirm by screenshot that no sentence breaks mid-line

Checked: `scripts/version.sh` prints 0.2.0; `--notes` for 0.1.1 (Unreleased removed temporarily) puts each wrapped bullet on one line; the release workflow YAML parses; the 0.2.0 notes plus the Install section were rendered with GitHub's Markdown API in gfm mode (newlines as breaks, like release pages), contained no <br>, and were screenshotted with all sections reading as whole lines.
