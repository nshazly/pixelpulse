# Product Roadmap

## Current State (v1.0)

PixelPulse is a macOS menu bar utility that fixes Samsung Odyssey G9 refresh rate desync by toggling display modes via Core Graphics APIs. It supports multi-display selection, manual target mode picking, launch-at-login, and a built-in log viewer. It also works on laptop built-in displays with variable refresh rates, and provides macOS-style resolution labels (Larger Text / Default / More Space) on Retina displays.

## Phase 1: Testing & Quality

### Unit Tests
- [x] `DisplayRefreshManager` logic tests (mode selection, resolution grouping, deduplication)
- [x] `RefreshStatus` state machine validation
- [x] `ModeOption` and `Resolution` model tests (equality, hashing, sorting, labels)
- [x] Resolution label tests (Retina scale descriptions, current marker)
- [x] Refresh rate label tests (default and VRR mode)
- [x] HiDPI detection and Show All Resolutions toggle behavior
- [ ] Error path coverage (no displays, single mode, CGDisplay API failures)

### UI Tests
- [ ] App launch and window presentation
- [ ] Display picker interaction
- [ ] Resolution and refresh rate picker state transitions
- [ ] Refresh button disabled states
- [ ] Menu bar extra presence and basic interaction
- [ ] Settings view toggle behavior

### Test Infrastructure
- [ ] Add mock/stub layer for `CGDisplayCopyAllDisplayModes` and related CG APIs to enable headless testing
- [ ] Establish minimum code coverage target (aim for 80%+ on business logic)

## Phase 2: Automated Installation & Distribution

### DMG Distribution
- [x] Automated `.dmg` build artifact creation in CI
- [x] GitHub Release publishing with DMG attachment (on `v*` tags)
- [x] Auto-generated release notes with categorized changelog
- [ ] Code-sign and notarize the app for Gatekeeper

### Homebrew Cask
- [ ] Create Homebrew Cask formula for `pixelpulse`
- [ ] Publish tap or submit to homebrew-cask

### Sparkle (Auto-Updates)
- [ ] Integrate Sparkle framework for in-app update checks
- [ ] Host appcast XML on GitHub Pages or releases
- [ ] Sign updates with EdDSA key

### Future Consideration
- [ ] Mac App Store submission (requires removing App Sandbox exceptions or adapting CG API usage)

## Phase 3: CI/CD Pipeline

### GitHub Actions
- [x] Build workflow: compile on every push and PR
- [x] Test workflow: run unit and UI test suites (`xcodebuild test`)
- [x] Release workflow: on tag push, build `.dmg`, create GitHub Release with artifact
- [ ] Lint workflow: SwiftLint checks on changed files
- [ ] Notarization step in release workflow

### Code Quality Gates
- [ ] Require passing tests before merge (branch protection rule)
- [ ] Require SwiftLint pass (no errors)
- [ ] Optional: code coverage reporting via Codecov or similar

## Phase 4: Feature Enhancements

- [ ] Auto-refresh on wake/display reconnect (register for `NSWorkspace` notifications)
- [ ] Profiles: save per-display mode preferences
- [ ] Keyboard shortcut customization
- [ ] Notification support (success/failure banners)
- [ ] Accessibility audit and VoiceOver support
- [ ] Localization (starting with common languages)

## Phase 5: Architecture & Polish

- [ ] Extract CG display interaction into a protocol for testability
- [ ] Migrate UI tests from XCTest to the Swift Testing + XCUIAutomation framework
- [ ] Adopt SwiftData or UserDefaults wrapper for persisted settings
- [ ] Dark/light mode asset review
- [ ] Performance profiling for mode enumeration on systems with many displays
