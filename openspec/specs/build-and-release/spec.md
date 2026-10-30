# build-and-release Specification

## Purpose

How Dockry is built, versioned, installed from source and released. The version comes from CHANGELOG.md, and every GitHub workflow runs only when started by hand.

## Requirements

### Requirement: Version from the changelog
Dockry's version SHALL be the first `## <version>` heading of CHANGELOG.md whose text is a dotted number; headings like `## Unreleased` are skipped. That version SHALL be stamped into every build and shown in Settings, and its section SHALL be the release notes.

#### Scenario: Unreleased section on top
- **WHEN** CHANGELOG.md starts with `## Unreleased` then `## 0.1.1`
- **THEN** the version is 0.1.1

### Requirement: App bundle
Building SHALL produce `build/Dockry.app` from a release build, with the bundle metadata, the icon and the version, signed with the local "Dockry Dev" certificate when it exists so macOS keeps Accessibility and Automation grants across builds, or ad hoc otherwise. A universal build SHALL cover Apple silicon and Intel.

#### Scenario: Rebuild keeps permissions
- **WHEN** the developer rebuilds with the "Dockry Dev" certificate installed
- **THEN** Dockry keeps its Accessibility access

### Requirement: Install from source
The install script SHALL build, install to /Applications and open Dockry, creating the signing certificate the first time. With `--profile-only` it SHALL install to `~/Applications` for the current account only, needing no admin rights and never touching another account's copy.

#### Scenario: Second account on the Mac
- **WHEN** a non-admin account runs the install script with `--profile-only`
- **THEN** Dockry is installed in that account's ~/Applications

### Requirement: Tests gate builds and releases
The unit tests SHALL run before screenshots are taken and before a release is built, and a failing test SHALL stop the workflow.

#### Scenario: Failing test
- **WHEN** a unit test fails during the Release workflow
- **THEN** nothing is tagged or published

### Requirement: Release once per version
The Release workflow SHALL fail if `Dockry-<version>` is already tagged; otherwise it SHALL tag the commit and publish a GitHub release with a disk image and a zip of the universal app and that version's notes.

#### Scenario: Version already released
- **WHEN** Release runs and Dockry-0.1.1 already exists
- **THEN** it fails and asks for a new version on top of CHANGELOG.md

### Requirement: Screenshots by CI
The Build & Screenshots workflow SHALL build, test, take the README screenshots on a hosted Mac and check Fast User Switching. On `dev` it commits the screenshots; on `dev-*` branches it publishes them to the `screenshots` branch, one folder per branch, instead.

#### Scenario: Feature branch
- **WHEN** the workflow runs on `dev-weather`
- **THEN** its screenshots go to the `screenshots` branch under that branch's folder and nothing is committed to `dev-weather`

### Requirement: Test hooks don't persist
UI states CI needs for screenshots (opening a popover or a Settings tab, sample Spotify, Claude usage and weather data) SHALL be reachable only through launch arguments, which macOS doesn't save, so they never stick in a real install.

#### Scenario: Normal launch
- **WHEN** Dockry is opened without arguments
- **THEN** no popover opens by itself and real data is used

### Requirement: Readable release notes
A version's release notes SHALL be its CHANGELOG.md section with wrapped lines joined: a line continues the one before it unless that one is blank or the line starts a new block (a list item, a heading, a numbered step, a quote). `###` subsections and Markdown inside the section SHALL be kept. The Release workflow SHALL end the notes with an Install section of numbered steps and the macOS and Mac requirements.

#### Scenario: Wrapped bullet
- **WHEN** a bullet in CHANGELOG.md is wrapped over two lines
- **THEN** the release notes have it on one line

#### Scenario: Subsections
- **WHEN** a version's section has `### What's new` and `### Fixes`
- **THEN** both headings and their bullets appear in the release notes, and the version is still read from the `## ` heading above them
