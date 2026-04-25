# CLAUDE.md - PixelPulse

## Project Overview

PixelPulse is a macOS menu bar utility that fixes Samsung Odyssey G9 refresh rate desync by programmatically toggling display modes via Core Graphics APIs. It targets macOS 14.0+ and is built with SwiftUI.

## Build & Run

```bash
# Build from command line
xcodebuild build -scheme PixelPulse -destination 'platform=macOS'

# Run tests
xcodebuild test -scheme PixelPulse -destination 'platform=macOS'
```

Or open `PixelPulse.xcodeproj` in Xcode and press Cmd+R.

## Project Structure

- `PixelPulse/` — App source: SwiftUI views, `DisplayRefreshManager`, assets
- `PixelPulseTests/` — Unit tests (Swift Testing framework)
- `PixelPulseUITests/` — UI tests (XCTest / XCUIAutomation)
- `Resources/` — Icon generation scripts
- `docs/` — Roadmap, standards, tool guides

## Architecture

Single `@Observable` class (`DisplayRefreshManager`) owns all state: display list, mode options, refresh status, log entries, and user preferences (`showVariableRefreshRate`, `showAllResolutions` via UserDefaults). SwiftUI views bind to it directly. The app entry point (`PixelPulseApp`) provides a `WindowGroup`, `Settings` scene, and `MenuBarExtra`, passing the manager to all scenes.

Core Graphics APIs used: `CGDisplayCopyAllDisplayModes` (with `kCGDisplayShowDuplicateLowResolutionModes`), `CGConfigureDisplayWithDisplayMode`, `CGBeginDisplayConfiguration`, `CGCompleteDisplayConfiguration`. Falls back to `NSScreen.maximumFramesPerSecond` when `CGDisplayMode.refreshRate` reports 0 (common on laptop built-in displays with variable refresh rates).

## Code Style

- Swift 5+ with strict concurrency (`MainActor` default isolation)
- `@Observable` over `ObservableObject`; `async`/`await` over Combine
- 4-space indentation, no trailing whitespace
- Minimal comments — only for non-obvious behavior
- See `docs/standards.md` for full conventions

## CI/CD

- `ci.yml` — Runs tests on push to `main` and PRs targeting `main` (macOS 15 runner, Xcode 16)
- `release.yml` — On `v*` tags: runs tests, builds Release DMG, publishes to GitHub Releases
- Release notes auto-generated from commits/PRs via `.github/release.yml` categories

## Key Constraints

- The app requires macOS display configuration permissions — CG APIs will fail in a sandboxed environment without entitlements
- Built-in laptop displays report `refreshRate == 0` from CG APIs — the app falls back to `NSScreen.maximumFramesPerSecond`
- Tests use real display APIs (`CGDisplayCopyAllDisplayModes`, etc.) — CI runners must have a display (macOS GitHub runners have virtual displays)
- Bundle identifier: `tickledbits.PixelPulse`

## Git Conventions

- Imperative mood commit messages, capitalize first word
- `main` is the default branch
- Feature branches: `feature/<name>`, bug fixes: `fix/<name>`
