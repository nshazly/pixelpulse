//
//  DisplayRefreshManager.swift
//  PixelPulse
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

struct Resolution: Hashable, Comparable {
    let width: Int
    let height: Int

    var label: String { "\(width) x \(height)" }

    static func < (lhs: Resolution, rhs: Resolution) -> Bool {
        if lhs.width != rhs.width { return lhs.width > rhs.width }
        return lhs.height > rhs.height
    }
}

struct ModeOption: Identifiable, Hashable {
    let id: Int32
    let width: Int
    let height: Int
    let refreshRate: Double
    let isVariableRate: Bool
    let isHiDPI: Bool
    let mode: CGDisplayMode

    var resolution: Resolution { Resolution(width: width, height: height) }
    var label: String { String(format: "%d x %d @ %.0f Hz", width, height, refreshRate) }

    static func == (lhs: ModeOption, rhs: ModeOption) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

@Observable
final class DisplayRefreshManager {
    var status: RefreshStatus = .ready
    var logEntries: [String] = []
    var displays: [DisplayInfo] = []
    var selectedDisplayID: CGDirectDisplayID = CGMainDisplayID()
    var currentModeDescription: String = "—"

    var allModeOptions: [ModeOption] = []
    var selectedResolution: Resolution?
    var selectedRefreshRate: Double?
    var currentResolution: Resolution?

    var showVariableRefreshRate: Bool = UserDefaults.standard.bool(forKey: "showVariableRefreshRate") {
        didSet {
            UserDefaults.standard.set(showVariableRefreshRate, forKey: "showVariableRefreshRate")
            reloadModes()
            updateCurrentModeDescription()
        }
    }

    var showAllResolutions: Bool = UserDefaults.standard.bool(forKey: "showAllResolutions") {
        didSet {
            UserDefaults.standard.set(showAllResolutions, forKey: "showAllResolutions")
            if let res = selectedResolution, !availableResolutions.contains(res) {
                selectedResolution = currentResolution ?? availableResolutions.first
                selectedRefreshRate = availableRefreshRates.first
            }
        }
    }

    var isRetinaDisplay: Bool {
        allModeOptions.contains(where: \.isHiDPI)
    }

    private var defaultResolution: Resolution? {
        let hiDPIResolutions = Array(Set(allModeOptions.filter(\.isHiDPI).map(\.resolution))).sorted()
        guard !hiDPIResolutions.isEmpty else { return nil }
        return hiDPIResolutions[hiDPIResolutions.count / 2]
    }

    var availableResolutions: [Resolution] {
        let modes = (!showAllResolutions && isRetinaDisplay)
            ? allModeOptions.filter(\.isHiDPI)
            : allModeOptions
        return Array(Set(modes.map(\.resolution))).sorted()
    }

    var availableRefreshRates: [Double] {
        guard let res = selectedResolution else { return [] }
        let modes = (!showAllResolutions && isRetinaDisplay)
            ? allModeOptions.filter { $0.isHiDPI && $0.resolution == res }
            : allModeOptions.filter { $0.resolution == res }
        return modes.map(\.refreshRate).uniqueSorted()
    }

    var selectedTargetMode: ModeOption? {
        guard let res = selectedResolution, let rate = selectedRefreshRate else { return nil }
        return allModeOptions.first {
            $0.resolution == res && $0.refreshRate == rate
        }
    }

    var modesGroupedByResolution: [(resolution: Resolution, modes: [ModeOption])] {
        let grouped = Dictionary(grouping: allModeOptions, by: \.resolution)
        return grouped.keys.sorted().map { res in
            (resolution: res, modes: grouped[res]!.sorted { $0.refreshRate > $1.refreshRate })
        }
    }

    func resolutionLabel(for res: Resolution) -> String {
        var parts = [res.label]
        if isRetinaDisplay, let defaultRes = defaultResolution {
            if res == defaultRes {
                parts.append("Default")
            } else if res.width > defaultRes.width {
                parts.append("More Space")
            } else {
                parts.append("Larger Text")
            }
        }
        if res == currentResolution {
            parts.append("current")
        }
        if parts.count > 1 {
            return "\(parts[0]) (\(parts[1 ..< parts.count].joined(separator: ", ")))"
        }
        return parts[0]
    }

    func refreshRateLabel(for rate: Double) -> String {
        guard showVariableRefreshRate, let res = selectedResolution else {
            return String(format: "%.0f Hz", rate)
        }
        if let mode = allModeOptions.first(where: { $0.resolution == res && $0.refreshRate == rate }), mode.isVariableRate {
            return String(format: "Variable (%.0f Hz)", rate)
        }
        return String(format: "%.0f Hz", rate)
    }

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PixelPulse", category: "DisplayMode")

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

        reloadModes()
    }

    func reloadModes() {
        let options = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue as Any] as CFDictionary
        guard let rawModes = CGDisplayCopyAllDisplayModes(selectedDisplayID, options) as? [CGDisplayMode] else {
            allModeOptions = []
            return
        }

        let fallbackRate = nominalRefreshRate(for: selectedDisplayID)

        allModeOptions = rawModes
            .map { mode in
                let isVariable = mode.refreshRate == 0
                let rate = mode.refreshRate > 0 ? mode.refreshRate : fallbackRate
                let hiDPI = mode.pixelWidth > mode.width
                return ModeOption(id: mode.ioDisplayModeID, width: mode.width, height: mode.height, refreshRate: rate, isVariableRate: isVariable, isHiDPI: hiDPI, mode: mode)
            }

        // Sort HiDPI first so dedup prefers them
        allModeOptions.sort { a, b in
            if a.isHiDPI != b.isHiDPI { return a.isHiDPI }
            return false
        }

        // Deduplicate by resolution + refresh rate + HiDPI, keeping first
        var seen = Set<String>()
        allModeOptions = allModeOptions.filter { mode in
            let key = "\(mode.width)x\(mode.height)@\(mode.refreshRate)@\(mode.isHiDPI)"
            return seen.insert(key).inserted
        }

        allModeOptions.sort { a, b in
            if a.width != b.width { return a.width > b.width }
            if a.height != b.height { return a.height > b.height }
            return a.refreshRate > b.refreshRate
        }

        // Default selection: current resolution, prefer a different refresh rate
        if let current = CGDisplayCopyDisplayMode(selectedDisplayID) {
            let currentRes = Resolution(width: current.width, height: current.height)
            currentResolution = currentRes
            selectedResolution = currentRes

            let currentRate = current.refreshRate > 0 ? current.refreshRate : fallbackRate
            selectedRefreshRate = allModeOptions
                .first(where: { $0.resolution == currentRes && $0.refreshRate != currentRate })?.refreshRate
                ?? allModeOptions.first(where: { $0.resolution == currentRes })?.refreshRate
        } else {
            selectedResolution = availableResolutions.first
            selectedRefreshRate = availableRefreshRates.first
        }
    }

    func updateCurrentModeDescription() {
        guard let mode = CGDisplayCopyDisplayMode(selectedDisplayID) else {
            currentModeDescription = "Unknown"
            return
        }
        currentResolution = Resolution(width: mode.width, height: mode.height)
        let isVariable = mode.refreshRate == 0
        let rate = mode.refreshRate > 0 ? mode.refreshRate : nominalRefreshRate(for: selectedDisplayID)
        if showVariableRefreshRate && isVariable {
            currentModeDescription = String(format: "%d x %d @ Variable (%.0f Hz)", mode.width, mode.height, rate)
        } else {
            currentModeDescription = String(format: "%d x %d @ %.0f Hz", mode.width, mode.height, rate)
        }
    }

    func performRefresh() {
        performRefreshWith(targetModeOption: selectedTargetMode)
    }

    func performRefreshWith(targetModeOption: ModeOption?) {
        Task { @MainActor in
            status = .switching
            logEntries = []
            let display = selectedDisplayID

            guard let currentMode = CGDisplayCopyDisplayMode(display) else {
                fail("Could not read current display mode")
                return
            }

            appendLog("Current: \(modeString(currentMode))")

            let targetMode: CGDisplayMode
            if let selected = targetModeOption {
                targetMode = selected.mode
                appendLog("Using selected target: \(selected.label)")
            } else {
                guard let allModes = CGDisplayCopyAllDisplayModes(display, nil) as? [CGDisplayMode],
                      allModes.count > 1 else {
                    fail("Not enough display modes available")
                    return
                }
                guard let auto = selectTargetMode(current: currentMode, allModes: allModes) else {
                    fail("Could not find a suitable alternate display mode")
                    return
                }
                targetMode = auto
            }

            appendLog("Target: \(modeString(targetMode))")

            appendLog("Switching to alternate mode...")
            guard setDisplayMode(display: display, mode: targetMode) else {
                fail("Failed to switch to alternate mode")
                return
            }
            logCurrentMode(display: display)

            appendLog("Waiting for display to stabilize (2s)...")
            try? await Task.sleep(for: .seconds(2))

            appendLog("Restoring original mode...")
            guard setDisplayMode(display: display, mode: currentMode) else {
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

    private func nominalRefreshRate(for displayID: CGDirectDisplayID) -> Double {
        for screen in NSScreen.screens {
            let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            if screenNumber == displayID {
                let fps = screen.maximumFramesPerSecond
                if fps > 0 { return Double(fps) }
            }
        }
        return 60.0
    }

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
            appendLog("Auto-selected: same resolution, different refresh rate")
            return mode
        }

        let diffRate = allModes.first {
            $0.refreshRate != current.refreshRate &&
            $0.refreshRate > 0
        }
        if let mode = diffRate {
            appendLog("Auto-selected: different resolution and refresh rate (fallback)")
            return mode
        }

        let anyDifferent = allModes.first {
            $0.ioDisplayModeID != current.ioDisplayModeID
        }
        if let mode = anyDifferent {
            appendLog("Auto-selected: any different mode (last resort)")
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
        let rate = mode.refreshRate > 0 ? mode.refreshRate : nominalRefreshRate(for: selectedDisplayID)
        return String(format: "Mode %d: %d x %d @ %.2f Hz", mode.ioDisplayModeID, mode.width, mode.height, rate)
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

private extension Array where Element == Double {
    func uniqueSorted() -> [Double] {
        Array(Set(self)).sorted(by: >)
    }
}
