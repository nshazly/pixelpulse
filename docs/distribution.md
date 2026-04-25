# PixelPulse Distribution Guide

## Recommended Build System: fastlane + xcodebuild

fastlane wraps `xcodebuild` and Apple's toolchain into a single declarative pipeline (`Fastfile`) that handles testing, building, code signing, notarization, and distribution from one command.

### Example Fastfile

```ruby
platform :mac do
  lane :test do
    scan(scheme: "PixelPulse", destination: "platform=macOS")
  end

  lane :build do
    gym(scheme: "PixelPulse", export_method: "developer-id")
  end

  lane :release do
    test
    build
    notarize(package: "path/to/PixelPulse.app", bundle_id: "tickledbits.PixelPulse")
  end
end
```

### Build System Comparison

| Criterion | fastlane | Raw xcodebuild scripts | Xcode Cloud | GitHub Actions + xcodebuild |
|---|---|---|---|---|
| Test suite integration | `scan` action, one line | Manual flags, manual parsing | Built-in but Apple-hosted only | Manual YAML, same flags as raw xcodebuild |
| Code signing | `match` manages certs/profiles automatically | Manual `security` + provisioning wrangling | Automatic but opaque | Same manual work as raw scripts |
| Notarization | `notarize` action with retry/stapling | 3-4 `xcrun notarytool` commands | Automatic for App Store | Manual scripting |
| Reproducibility | Declarative `Fastfile` checked into repo | Shell scripts drift | Tied to Apple's infra | YAML config, but signing is painful |
| Learning curve | Moderate (Ruby DSL) | Low (but grows complex fast) | Low (but limited flexibility) | Moderate |
| CI agnostic | Runs anywhere: local, GitHub Actions, Jenkins | Same | Apple-only | GitHub-only |

### Why fastlane

- Declarative and version-controlled via a `Fastfile` in the repo
- Handles the full lifecycle: test, build, sign, notarize, distribute
- `match` eliminates manual certificate and provisioning profile management
- Runs identically on local machines and any CI provider
- Large plugin ecosystem (400+ integrations)

---

## Package Formats

### Recommended: DMG with Notarized .app (Direct Distribution)

PixelPulse uses Core Graphics display configuration APIs (`CGBeginDisplayConfiguration`, `CGConfigureDisplayWithDisplayMode`) that require permissions conflicting with App Sandbox restrictions. Direct distribution outside the Mac App Store is the recommended primary path.

**How it works:**
1. User downloads `.dmg`
2. Opens it and drags `PixelPulse.app` to `/Applications`
3. Gatekeeper shows "identified developer" — no warnings

**Signing and notarization:**
- Code-sign with a **Developer ID Application** certificate
- Submit the DMG to Apple's notarization service, then staple the ticket

**Build commands:**
```shell
# Build the app
xcodebuild build -scheme PixelPulse -configuration Release -destination 'platform=macOS'

# Create the DMG
hdiutil create -volname PixelPulse -srcfolder build/PixelPulse.app -ov PixelPulse.dmg

# Notarize
xcrun notarytool submit PixelPulse.dmg --apple-id <APPLE_ID> --team-id <TEAM_ID> --password <APP_SPECIFIC_PASSWORD> --wait

# Staple
xcrun stapler staple PixelPulse.dmg
```

### Alternative 1: Installer Package (.pkg)

```shell
productbuild --sign "Developer ID Installer: ..." --component PixelPulse.app /Applications PixelPulse.pkg
```

- **Pros:** Can run pre/post-install scripts, install to custom locations, install helper tools or launch daemons
- **Cons:** Heavier UX for a simple menu bar app; users must click through an installer wizard
- **When to use:** If PixelPulse later needs a privileged helper tool (e.g., a LaunchDaemon for background display monitoring)

### Alternative 2: Homebrew Cask

```ruby
cask "pixelpulse" do
  version "1.0.0"
  sha256 "abc123..."
  url "https://github.com/user/PixelPulse/releases/download/v#{version}/PixelPulse.dmg"
  name "PixelPulse"
  homepage "https://github.com/user/PixelPulse"
  app "PixelPulse.app"
end
```

- **Pros:** `brew install --cask pixelpulse` — developer-friendly, auto-updates via `brew upgrade`
- **Cons:** Requires maintaining a cask formula in the homebrew-cask repo (or a personal tap); only reaches users who use Homebrew
- **When to use:** As a secondary distribution channel alongside DMG. Publish the DMG to GitHub Releases, then point the cask at it

### Alternative 3: Sparkle Framework (Auto-Updates)

- Embed the Sparkle framework in the app for automatic update checks against an appcast XML feed
- Pairs with DMG distribution — users install once, then receive in-app updates
- Worth adding once there is a stable release cadence

### Format Comparison

| Format | Best For | Complexity | User Familiarity |
|---|---|---|---|
| **DMG** | Simple apps, drag-to-install | Low | High |
| **.pkg** | Apps needing install scripts/helpers | Medium | Medium |
| **Homebrew Cask** | Developer audience | Medium (maintenance) | High (for devs) |
| **Sparkle** | Auto-updates after initial install | Medium | Transparent |

---

## Mac App Store Distribution Requirements

### 1. Apple Developer Program Membership

- Paid enrollment ($99/year) at developer.apple.com
- Required for App Store distribution certificates and App Store Connect access

### 2. App Sandbox (Mandatory)

- All Mac App Store apps **must** enable the App Sandbox entitlement
- **This is the primary blocker for PixelPulse:** `CGBeginDisplayConfiguration` and `CGConfigureDisplayWithDisplayMode` require unsandboxed access to the display subsystem
- Possible workarounds:
  - Request a temporary entitlement exception from Apple (unlikely to be granted for this use case)
  - Refactor to use a privileged helper tool via `SMAppService` that runs outside the sandbox while the main app remains sandboxed

### 3. Code Signing

- Sign with a **Mac App Distribution** certificate (not Developer ID)
- Provisioning profiles must be embedded and must allowlist all restricted entitlements
- Xcode 16+ validates that provisioning profiles cover all restricted entitlements at build time

### 4. Hardened Runtime

- Must be enabled (Xcode enforces this for distribution builds)
- Declare only the runtime exceptions actually needed

### 5. App Store Connect Configuration

- Create an app record with bundle ID `tickledbits.PixelPulse`
- Provide: app name, description, screenshots, category (Utilities), privacy policy URL, age rating
- Set pricing (free or paid)

### 6. App Review Guidelines Compliance

- No private API usage
- Must provide value beyond a simple settings toggle
- Must handle errors gracefully
- Must support the platforms declared
- Review guideline 2.4.5: apps that manage system configuration must do so transparently

### 7. Submission Pipeline

- Build an archive in Xcode or via `gym` with `export_method: "app-store"`
- Upload via Xcode Organizer, `xcrun altool`, or fastlane's `deliver` action
- Submit for review through App Store Connect

### 8. Ongoing Requirements

- Must stay compatible with latest macOS versions
- Must respond to Apple's review feedback within a reasonable timeframe
- Binary must be 64-bit (universal binary recommended for Apple Silicon + Intel)

---

## Recommended Rollout Plan

1. **Immediate:** Set up fastlane with `scan` (test) + `gym` (build) + `notarize` lanes, producing a signed and notarized DMG. Distribute via GitHub Releases.
2. **Short-term:** Add a Homebrew Cask pointing at GitHub Releases for developer convenience.
3. **Medium-term:** Integrate Sparkle for auto-updates once there is a regular release cadence.
4. **Long-term:** Investigate a privileged helper architecture (`SMAppService`) to make the app sandbox-compatible for Mac App Store distribution.
