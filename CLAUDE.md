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

Single `@Observable` class (`DisplayRefreshManager`) owns all state: display list, mode options, refresh status, and log entries. SwiftUI views bind to it directly. The app entry point (`PixelPulseApp`) provides a `WindowGroup`, `Settings` scene, and `MenuBarExtra`.

Core Graphics APIs used: `CGDisplayCopyAllDisplayModes`, `CGConfigureDisplayWithDisplayMode`, `CGBeginDisplayConfiguration`, `CGCompleteDisplayConfiguration`.

## Code Style

- Swift 5+ with strict concurrency (`MainActor` default isolation)
- `@Observable` over `ObservableObject`; `async`/`await` over Combine
- 4-space indentation, no trailing whitespace
- Minimal comments — only for non-obvious behavior
- See `docs/standards.md` for full conventions

## Key Constraints

- The app requires macOS display configuration permissions — CG APIs will fail in a sandboxed environment without entitlements
- Tests that exercise `CGDisplayCopyAllDisplayModes` need a real display or a mock abstraction layer (not yet implemented)
- Bundle identifier: `tickledbits.PixelPulse`

## Git Conventions

- Imperative mood commit messages, capitalize first word
- `main` is the default branch
- Feature branches: `feature/<name>`, bug fixes: `fix/<name>`
