# Spec Delta

## ADDED Requirements

### Requirement: Readable release notes
A version's release notes SHALL be its CHANGELOG.md section with wrapped lines joined: a line continues the one before it unless that one is blank or the line starts a new block (a list item, a heading, a numbered step, a quote). `###` subsections and Markdown inside the section SHALL be kept. The Release workflow SHALL end the notes with an Install section of numbered steps and the macOS and Mac requirements.

#### Scenario: Wrapped bullet
- **WHEN** a bullet in CHANGELOG.md is wrapped over two lines
- **THEN** the release notes have it on one line

#### Scenario: Subsections
- **WHEN** a version's section has `### What's new` and `### Fixes`
- **THEN** both headings and their bullets appear in the release notes, and the version is still read from the `## ` heading above them
