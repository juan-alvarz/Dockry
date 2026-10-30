# Design

## Context

`scripts/version.sh` prints the first dotted `## <version>` heading, or with `--notes` the
lines up to the next `## ` heading, which the Release workflow passes to
`gh release create --notes` with two paragraphs appended. GitHub renders release bodies with
hard line breaks.

## Decisions

- **Unwrap in the script, not in the file.** The awk in `version.sh --notes` buffers a
  paragraph and joins continuation lines with a space (trimming their indent); a blank line,
  or a line starting with `- `, `* `, `#`, `>`, a numbered step or a code fence, starts a new
  block. Code fences pass through untouched. Alternative considered: unwrapped lines in
  CHANGELOG.md — rejected, the file is read in editors and diffs too.
- `### ` headings don't end a version's section: only `## ` does (the pattern is `^## `,
  which `### ` doesn't match), so subsections already work with the version lookup.
- **Install text** moves into the workflow as `### Install` with numbered steps and a
  requirements line, linking the README for permissions.

## Risks / Trade-offs

- [A line meant as a hard break inside a paragraph gets joined] → write it as its own
  bullet or paragraph; the CHANGELOG header says so.
