# PixelPulse

A lightweight macOS utility that fixes the Samsung Odyssey G9 refresh rate synchronization bug by programmatically toggling display modes.

## The Problem

The Samsung Odyssey G9 (5120x1440 @ 240Hz) has a well-documented issue on macOS where the refresh rate fails to properly synchronize after sleep/wake cycles, reconnection, or reboots. macOS may report 240Hz but the display actually renders at a lower refresh rate (often 60Hz), resulting in visible stuttering and degraded performance.

This issue is related to Display Stream Compression (DSC) at ultra-wide resolutions and has not been fully resolved by Samsung firmware updates or macOS system updates.

## The Solution

PixelPulse automates the known workaround: it switches to an alternate display mode (different refresh rate) and then switches back to the original mode. This forces macOS to renegotiate the display link, restoring the correct refresh rate.

The app intelligently selects a target mode by:
1. Preferring a mode with the **same resolution** but a different refresh rate
2. Falling back to any mode with a different refresh rate
3. Allowing a 2-second stabilization delay between switches

You can also manually select the intermediate resolution and refresh rate from the dropdowns or the menu bar.

## Features

- **One-click refresh** — Fix your display with a single button press or keyboard shortcut (Cmd+R)
- **Selectable target mode** — Choose the intermediate resolution and refresh rate, or let the app pick automatically
- **Multi-display support** — Detects all connected displays and lets you choose which to refresh
- **Menu bar access** — Quick refresh from the macOS menu bar, with a "Switch via..." submenu listing all available modes grouped by resolution
- **Launch at login** — Optionally start the app automatically when you log in (Settings > Launch at Login)
- **Smart mode selection** — Automatically picks the best alternate display mode for the toggle
- **Detailed logging** — See exactly what the app is doing in the built-in log viewer

## Requirements

- macOS 14.0 (Sonoma) or later
- A Mac with an external display (designed for Samsung Odyssey G9, but works with any display)

## Installation

### From Releases

Download the latest `.dmg` from the [Releases](../../releases) page and drag PixelPulse to your Applications folder.

### Build from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/nshazly/pixelpulse.git
   ```
2. Open `PixelPulse.xcodeproj` in Xcode
3. Build and run (Cmd+R)

## Usage

1. Launch PixelPulse
2. Select your display from the dropdown (defaults to the main display)
3. Optionally choose a target resolution and refresh rate under "Switch via"
4. Click **Refresh Display** or press **Cmd+R**
5. Wait for the mode switch cycle to complete (~2 seconds)

For quick access, use the menu bar icon to refresh without opening the main window. The "Switch via..." submenu lets you pick any available mode directly.

## How It Works

The app uses the Core Graphics display configuration APIs (`CGDisplayCopyAllDisplayModes`, `CGConfigureDisplayWithDisplayMode`) to:

1. Read the current display mode
2. Find a suitable alternate mode with a different refresh rate
3. Switch to the alternate mode
4. Wait for the display hardware to stabilize
5. Switch back to the original mode

This forces macOS to renegotiate the display link protocol, which resolves the refresh rate desynchronization.

## License

MIT License. See [LICENSE](LICENSE) for details.
