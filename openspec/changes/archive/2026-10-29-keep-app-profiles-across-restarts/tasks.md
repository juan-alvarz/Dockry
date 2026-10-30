# Tasks

## 1. Core

- [x] 1.1 Add `AppOwnership` (Codable entries, `profile(forPID:launchedAt:)` with a one-second tolerance) and verify with new tests: same process, reused pid, missing launch date, JSON round trip

## 2. App

- [x] 2.1 Save and load `ProfileApps` ownership through `AppOwnership` under `appOwners`, remove `appProfiles`, and verify `swift build`
- [x] 2.2 Replace window records whose pid doesn't match the scanned app in `ProfileWindows.scan`, and verify `swift build`
