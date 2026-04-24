# Pre-Commit Hooks

## Overview

Pre-commit hooks run automatically before each `git commit` to catch issues early. This project will use them to enforce code quality without relying solely on CI.

## Planned Setup

### SwiftLint

[SwiftLint](https://github.com/realm/SwiftLint) enforces Swift style and conventions.

**Install:**
```bash
brew install swiftlint
```

**Hook script** (`.git/hooks/pre-commit`):
```bash
#!/bin/bash

# Run SwiftLint on staged Swift files only
STAGED=$(git diff --cached --name-only --diff-filter=ACM | grep '\.swift$')

if [ -z "$STAGED" ]; then
    exit 0
fi

echo "$STAGED" | xargs swiftlint lint --strict --quiet
if [ $? -ne 0 ]; then
    echo "SwiftLint violations found. Fix them before committing."
    exit 1
fi
```

```bash
chmod +x .git/hooks/pre-commit
```

### SwiftFormat (Optional)

[SwiftFormat](https://github.com/nicklockwood/SwiftFormat) can auto-format code on commit.

```bash
brew install swiftformat
```

Add to the pre-commit hook:
```bash
echo "$STAGED" | xargs swiftformat --lint
```

### Build Check (Optional, Heavyweight)

For critical branches, a pre-commit hook can run a quick build:
```bash
xcodebuild build -scheme PixelPulse -destination 'platform=macOS' -quiet 2>/dev/null
```

This is slow and generally better suited to CI, but useful as a pre-push hook.

## Shared Hooks with `git config`

To share hooks across the team without modifying `.git/hooks/` directly:

```bash
mkdir -p .githooks
# Move hook scripts into .githooks/
git config core.hooksPath .githooks
```

Commit the `.githooks/` directory so all contributors use the same hooks.

## Status

- [ ] Add `.swiftlint.yml` configuration
- [ ] Create `.githooks/pre-commit` script
- [ ] Set `core.hooksPath` in project setup instructions
- [ ] Document in README or contributing guide
