# Context7 for Documentation Lookup

## Overview

[Context7](https://context7.com) provides up-to-date library documentation directly in the terminal via `npx ctx7@latest`. It is an **opt-in, manual tool** — invoke it on demand whenever you need current API documentation while working on this project.

## How It Works

1. **Resolve library** - find the Context7 ID for a library:
   ```bash
   npx ctx7@latest library <name> "<question>"
   ```
2. **Fetch docs** - retrieve relevant documentation:
   ```bash
   npx ctx7@latest docs <libraryId> "<question>"
   ```

## When to Use It

Invoke Context7 manually when you need accurate, up-to-date docs for:
- SwiftUI APIs, view modifiers, or lifecycle
- Core Graphics / AppKit display APIs
- ServiceManagement (launch-at-login)
- Any third-party dependency added in the future (e.g., Sparkle, SwiftLint)
- CLI tools and their flags

## Why

Training data for AI models can be months behind the latest SDK releases. Context7 ensures answers reflect the current API surface, which is particularly important for:
- SwiftUI (APIs change significantly each WWDC cycle)
- macOS SDK deprecations and replacements
- New frameworks (e.g., FoundationModels, Liquid Glass design system)

## Setup

No project-level configuration is required. You only need `npx` available (ships with Node.js). Run commands on demand from the project root whenever you need up-to-date documentation.

## Rate Limits

If you hit quota errors, authenticate for higher limits:
```bash
npx ctx7@latest login
```
Or set the `CONTEXT7_API_KEY` environment variable.
