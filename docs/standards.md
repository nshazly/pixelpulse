# Project Standards & Tech Stack

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5+ with strict concurrency (`SWIFT_APPROACHABLE_CONCURRENCY`, `MainActor` default isolation) |
| UI Framework | SwiftUI (macOS 14.0+) |
| System APIs | Core Graphics (`CGDisplayCopyAllDisplayModes`, `CGConfigureDisplayWithDisplayMode`), AppKit (display enumeration), ServiceManagement (launch-at-login) |
| Architecture | Single-`@Observable` manager (`DisplayRefreshManager`) consumed by SwiftUI views |
| Testing | Swift Testing framework (unit), XCTest/XCUIAutomation (UI) |
| Build System | Xcode / xcodebuild |
| Version Control | Git, hosted on GitHub |
| Minimum Target | macOS 14.0 (Sonoma) |

## Code Style

### Naming
- **Types**: `PascalCase` (e.g., `DisplayRefreshManager`, `ModeOption`)
- **Properties & methods**: `camelCase`
- **Enum cases**: `camelCase`

### SwiftUI
- Use `@State private var` for view-local state
- Use `@Bindable` when passing `@Observable` objects to child views
- Use `@Observable` (not `ObservableObject`/`@Published`) for model classes
- Define UI composition in computed properties (`headerSection`, `logSection`), not deeply nested `body` closures

### Concurrency
- Prefer `async`/`await` over Combine
- Use `Task { @MainActor in ... }` for UI-bound async work
- Default actor isolation is `MainActor` (project setting)

### Formatting
- 4-space indentation
- No trailing whitespace
- One blank line between logical sections
- `MARK` comments to separate view sections

### Imports
- Keep imports minimal and explicit (`SwiftUI`, `CoreGraphics`, `os`, etc.)
- Alphabetical order preferred

### Error Handling
- Use `Result` or throwing functions for recoverable errors
- Log errors via `os.Logger` before surfacing to the user
- Avoid force-unwrapping (`!`) except for IB outlets or genuinely impossible nil cases

### Comments
- No comments on self-explanatory code
- Brief inline comments only for non-obvious behavior (e.g., CG API quirks, hardware-specific workarounds)

## Git Conventions

### Commit Messages
- Imperative mood, capitalize first word (e.g., "Add selectable display modes")
- Keep the subject line under 72 characters
- Body is optional; use it for *why*, not *what*

### Branching
- `main` is the default and release branch
- Feature branches: `feature/<short-description>`
- Bug fixes: `fix/<short-description>`

## Project Structure

```
PixelPulse/
  PixelPulse/            # App source (SwiftUI views, managers, assets)
  PixelPulseTests/       # Unit tests (Swift Testing)
  PixelPulseUITests/     # UI tests (XCTest / XCUIAutomation)
  PixelPulse.xcodeproj/  # Xcode project
  Resources/             # Icon generation scripts, static assets
  docs/                  # Project documentation
  CLAUDE.md              # AI assistant project context
  README.md              # Public-facing project description
  LICENSE                # MIT License
```
