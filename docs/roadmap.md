# Product Roadmap

## Current State (v1.0)

PixelPulse is a macOS menu bar utility that fixes Samsung Odyssey G9 refresh rate desync by toggling display modes via Core Graphics APIs. It supports multi-display selection, manual target mode picking, launch-at-login, and a built-in log viewer.

## Phase 1: Testing & Quality

### Unit Tests
- [ ] `DisplayRefreshManager` logic tests (mode selection, resolution grouping, deduplication)
- [ ] `RefreshStatus` state machine validation
- [ ] `ModeOption` and `Resolution` model tests (equality, hashing, sorting, labels)
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

### Homebrew Cask
- [ ] Create Homebrew Cask formula for `pixelpulse`
- [ ] Automate `.dmg` or `.zip` build artifact creation in CI
- [ ] Code-sign and notarize the app for Gatekeeper
- [ ] Publish tap or submit to homebrew-cask

### Sparkle (Auto-Updates)
- [ ] Integrate Sparkle framework for in-app update checks
- [ ] Host appcast XML on GitHub Pages or releases
- [ ] Sign updates with EdDSA key

### Future Consideration
- [ ] Mac App Store submission (requires removing App Sandbox exceptions or adapting CG API usage)

## Phase 3: CI/CD Pipeline

### GitHub Actions
- [ ] Build workflow: compile on every push and PR (`xcodebuild build`)
- [ ] Test workflow: run unit and UI test suites (`xcodebuild test`)
- [ ] Lint workflow: SwiftLint checks on changed files
- [ ] Release workflow: on tag push, build signed `.dmg`, notarize, create GitHub Release with artifact

### Code Quality Gates
- [ ] Require passing tests before merge
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
