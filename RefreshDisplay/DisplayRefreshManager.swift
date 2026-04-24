//
//  DisplayRefreshManager.swift
//  RefreshDisplay
//
//  Created by Neill Shazly on 2026-03-23.
//

import SwiftUI
import os
import CoreGraphics
import AppKit

enum RefreshStatus: Equatable {
    case ready
    case switching
    case completed
    case error(String)

    var label: String {
        switch self {
        case .ready: return "Ready"
        case .switching: return "Switching display mode..."
        case .completed: return "Completed"
        case .error(let msg): return "Error: \(msg)"
        }
    }

    var color: Color {
        switch self {
        case .ready: return .secondary
        case .switching: return .orange
        case .completed: return .green
        case .error: return .red
        }
    }
}

struct DisplayInfo: Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String
    let isMain: Bool
}

@Observable
final class DisplayRefreshManager {
    var status: RefreshStatus = .ready
    var logEntries: [String] = []
    var displays: [DisplayInfo] = []
    var selectedDisplayID: CGDirectDisplayID = CGMainDisplayID()
    var currentModeDescription: String = "—"

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "RefreshDisplay", category: "DisplayMode")

    func refreshDisplayList() {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)

        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displayIDs, &displayCount)

        displays = displayIDs.map { id in
            let name = displayName(for: id)
            return DisplayInfo(id: id, name: name, isMain: id == CGMainDisplayID())
        }

        if !displays.contains(where: { $0.id == selectedDisplayID }) {
            selectedDisplayID = CGMainDisplayID()
        }

        appendLog("Detected \(displays.count) display(s)")
        for display in displays {
            appendLog("  \(display.name)\(display.isMain ? " (main)" : "")")
        }
    }

    func updateCurrentModeDescription() {
        guard let mode = CGDisplayCopyDisplayMode(selectedDisplayID) else {
            currentModeDescription = "Unknown"
            return
        }
        currentModeDescription = String(
            format: "%d x %d @ %.0f Hz",
            mode.width, mode.height, mode.refreshRate
        )
    }

    func performRefresh() {
        Task { @MainActor in
            status = .switching
            logEntries = []
            let display = selectedDisplayID

            guard let currentMode = CGDisplayCopyDisplayMode(display) else {
                fail("Could not read current display mode")
                return
            }

            appendLog("Current: \(modeString(currentMode))")

            guard let allModes = CGDisplayCopyAllDisplayModes(display, nil) as? [CGDisplayMode],
                  allModes.count > 1 else {
                fail("Not enough display modes available")
                return
            }

            appendLog("Found \(allModes.count) available modes")

            guard let targetMode = selectTargetMode(current: currentMode, allModes: allModes) else {
                fail("Could not find a suitable alternate display mode")
                return
            }

            appendLog("Target: \(modeString(targetMode))")

            appendLog("Switching to alternate mode...")
            let switchResult = setDisplayMode(display: display, mode: targetMode)
            guard switchResult else {
                fail("Failed to switch to alternate mode")
                return
            }
            logCurrentMode(display: display)

            appendLog("Waiting for display to stabilize (2s)...")
            try? await Task.sleep(for: .seconds(2))

            appendLog("Restoring original mode...")
            let restoreResult = setDisplayMode(display: display, mode: currentMode)
            guard restoreResult else {
                fail("Failed to restore original mode")
                return
            }
            logCurrentMode(display: display)

            updateCurrentModeDescription()
            status = .completed
            appendLog("Refresh complete.")
        }
    }

    // MARK: - Private

    private func displayName(for displayID: CGDirectDisplayID) -> String {
        for screen in NSScreen.screens {
            let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            if screenNumber == displayID {
                return screen.localizedName
            }
        }

        let width = CGDisplayPixelsWide(displayID)
        let height = CGDisplayPixelsHigh(displayID)
        let isMain = displayID == CGMainDisplayID()
        return isMain ? "Main Display (\(width)x\(height))" : "Display \(displayID) (\(width)x\(height))"
    }

    private func selectTargetMode(current: CGDisplayMode, allModes: [CGDisplayMode]) -> CGDisplayMode? {
        let sameResDiffRate = allModes.first {
            $0.width == current.width &&
            $0.height == current.height &&
            $0.refreshRate != current.refreshRate &&
            $0.refreshRate > 0
        }
        if let mode = sameResDiffRate {
            appendLog("Selected mode: same resolution, different refresh rate")
            return mode
        }

        let diffRate = allModes.first {
            $0.refreshRate != current.refreshRate &&
            $0.refreshRate > 0
        }
        if let mode = diffRate {
            appendLog("Selected mode: different resolution and refresh rate (fallback)")
            return mode
        }

        let anyDifferent = allModes.first {
            $0.ioDisplayModeID != current.ioDisplayModeID
        }
        if let mode = anyDifferent {
            appendLog("Selected mode: any different mode (last resort)")
            return mode
        }

        return nil
    }

    private func setDisplayMode(display: CGDirectDisplayID, mode: CGDisplayMode) -> Bool {
        let config = UnsafeMutablePointer<CGDisplayConfigRef?>.allocate(capacity: 1)
        defer { config.deallocate() }

        let beginErr = CGBeginDisplayConfiguration(config)
        guard beginErr == .success else {
            appendLog("CGBeginDisplayConfiguration failed: \(beginErr.rawValue)")
            return false
        }

        CGConfigureDisplayWithDisplayMode(config.pointee, display, mode, nil)

        let completeErr = CGCompleteDisplayConfiguration(config.pointee, .permanently)
        guard completeErr == .success else {
            appendLog("CGCompleteDisplayConfiguration failed: \(completeErr.rawValue)")
            return false
        }

        return true
    }

    private func logCurrentMode(display: CGDirectDisplayID) {
        if let mode = CGDisplayCopyDisplayMode(display) {
            appendLog("  Now: \(modeString(mode))")
        }
    }

    private func modeString(_ mode: CGDisplayMode) -> String {
        String(format: "Mode %d: %d x %d @ %.2f Hz", mode.ioDisplayModeID, mode.width, mode.height, mode.refreshRate)
    }

    func appendLog(_ message: String) {
        logger.log("\(message)")
        logEntries.append(message)
    }

    private func fail(_ message: String) {
        logger.error("\(message)")
        appendLog("ERROR: \(message)")
        status = .error(message)
    }
}
