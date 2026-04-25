//
//  PixelPulseTests.swift
//  PixelPulseTests
//
//  Created by Neill Shazly on 2026-03-23.
//

import Testing
import CoreGraphics
import AppKit
@testable import PixelPulse

// MARK: - RefreshStatus Tests

@MainActor
struct RefreshStatusTests {
    @Test func readyLabel() {
        #expect(RefreshStatus.ready.label == "Ready")
    }

    @Test func switchingLabel() {
        #expect(RefreshStatus.switching.label == "Switching display mode...")
    }

    @Test func completedLabel() {
        #expect(RefreshStatus.completed.label == "Completed")
    }

    @Test func errorLabel() {
        let status = RefreshStatus.error("test failure")
        #expect(status.label == "Error: test failure")
    }

    @Test func equality() {
        #expect(RefreshStatus.ready == RefreshStatus.ready)
        #expect(RefreshStatus.error("a") == RefreshStatus.error("a"))
        #expect(RefreshStatus.error("a") != RefreshStatus.error("b"))
        #expect(RefreshStatus.ready != RefreshStatus.switching)
    }
}

// MARK: - Resolution Tests

@MainActor
struct ResolutionTests {
    @Test func label() {
        let res = Resolution(width: 1920, height: 1080)
        #expect(res.label == "1920 x 1080")
    }

    @Test func sortingLargestFirst() {
        let resolutions = [
            Resolution(width: 1280, height: 720),
            Resolution(width: 1920, height: 1080),
            Resolution(width: 3840, height: 2160),
        ]
        let sorted = resolutions.sorted()
        #expect(sorted[0].width == 3840)
        #expect(sorted[1].width == 1920)
        #expect(sorted[2].width == 1280)
    }

    @Test func sortingTiebreaksByHeight() {
        let a = Resolution(width: 1920, height: 1200)
        let b = Resolution(width: 1920, height: 1080)
        let sorted = [a, b].sorted()
        #expect(sorted[0].height == 1200)
        #expect(sorted[1].height == 1080)
    }

    @Test func hashable() {
        let a = Resolution(width: 1920, height: 1080)
        let b = Resolution(width: 1920, height: 1080)
        #expect(a == b)
        let set: Set<Resolution> = [a, b]
        #expect(set.count == 1)
    }
}

// MARK: - DisplayRefreshManager Tests

@MainActor
struct DisplayRefreshManagerTests {

    private func makeManager() -> DisplayRefreshManager {
        DisplayRefreshManager()
    }

    @Test func initialState() {
        let manager = makeManager()
        #expect(manager.status == .ready)
        #expect(manager.logEntries.isEmpty)
        #expect(manager.currentModeDescription == "—")
        #expect(manager.selectedResolution == nil)
        #expect(manager.selectedRefreshRate == nil)
    }

    @Test func appendLogAddsEntries() {
        let manager = makeManager()
        manager.appendLog("first")
        manager.appendLog("second")
        #expect(manager.logEntries.count == 2)
        #expect(manager.logEntries[0] == "first")
        #expect(manager.logEntries[1] == "second")
    }

    @Test func refreshDisplayListPopulatesDisplays() {
        let manager = makeManager()
        manager.refreshDisplayList()
        #expect(!manager.displays.isEmpty)
        let hasMain = manager.displays.contains(where: \.isMain)
        #expect(hasMain)
    }

    @Test func reloadModesPopulatesOptions() {
        let manager = makeManager()
        manager.refreshDisplayList()
        #expect(!manager.allModeOptions.isEmpty)
        #expect(manager.selectedResolution != nil)
    }

    @Test func availableResolutionsNotEmpty() {
        let manager = makeManager()
        manager.refreshDisplayList()
        #expect(!manager.availableResolutions.isEmpty)
    }

    @Test func availableResolutionsSorted() {
        let manager = makeManager()
        manager.refreshDisplayList()
        let resolutions = manager.availableResolutions
        for i in 0 ..< resolutions.count - 1 {
            #expect(resolutions[i] < resolutions[i + 1])
        }
    }

    @Test func availableRefreshRatesForSelectedResolution() {
        let manager = makeManager()
        manager.refreshDisplayList()
        #expect(manager.selectedResolution != nil)
        let rates = manager.availableRefreshRates
        #expect(!rates.isEmpty)
        // Rates should be sorted descending
        for i in 0 ..< rates.count - 1 {
            #expect(rates[i] > rates[i + 1])
        }
    }

    @Test func currentResolutionSetAfterRefresh() {
        let manager = makeManager()
        manager.refreshDisplayList()
        manager.updateCurrentModeDescription()
        #expect(manager.currentResolution != nil)
        #expect(manager.currentModeDescription != "—")
        #expect(manager.currentModeDescription != "Unknown")
    }

    @Test func defaultSelectionPrefersDifferentRate() {
        let manager = makeManager()
        manager.refreshDisplayList()
        let rates = manager.availableRefreshRates
        if rates.count > 1, let currentMode = CGDisplayCopyDisplayMode(CGMainDisplayID()) {
            let fallback = Double(NSScreen.main?.maximumFramesPerSecond ?? 60)
            let currentRate = currentMode.refreshRate > 0 ? currentMode.refreshRate : fallback
            // When multiple rates exist, the selected rate should differ from current
            #expect(manager.selectedRefreshRate != currentRate)
        }
    }

    @Test func selectedTargetModeMatchesSelection() {
        let manager = makeManager()
        manager.refreshDisplayList()
        if let res = manager.selectedResolution, let rate = manager.selectedRefreshRate {
            let target = manager.selectedTargetMode
            #expect(target != nil)
            #expect(target?.resolution == res)
            #expect(target?.refreshRate == rate)
        }
    }

    @Test func modesGroupedByResolution() {
        let manager = makeManager()
        manager.refreshDisplayList()
        let grouped = manager.modesGroupedByResolution
        #expect(!grouped.isEmpty)
        for group in grouped {
            #expect(!group.modes.isEmpty)
            for mode in group.modes {
                #expect(mode.resolution == group.resolution)
            }
        }
    }

    // MARK: - Resolution Label Tests

    @Test func resolutionLabelIncludesCurrentMarker() {
        let manager = makeManager()
        manager.refreshDisplayList()
        manager.updateCurrentModeDescription()
        guard let current = manager.currentResolution else { return }
        let label = manager.resolutionLabel(for: current)
        #expect(label.contains("current"))
    }

    @Test func resolutionLabelForNonCurrentOmitsCurrent() {
        let manager = makeManager()
        manager.refreshDisplayList()
        manager.updateCurrentModeDescription()
        let fakeRes = Resolution(width: 99999, height: 99999)
        let label = manager.resolutionLabel(for: fakeRes)
        #expect(!label.contains("current"))
    }

    @Test func resolutionLabelRetinaScaleDescriptions() {
        let manager = makeManager()
        manager.refreshDisplayList()
        guard manager.isRetinaDisplay else { return }
        let resolutions = manager.availableResolutions
        guard resolutions.count >= 3 else { return }
        let largest = resolutions.first!
        let smallest = resolutions.last!
        #expect(manager.resolutionLabel(for: largest).contains("More Space"))
        #expect(manager.resolutionLabel(for: smallest).contains("Larger Text"))
    }

    // MARK: - Refresh Rate Label Tests

    @Test func refreshRateLabelDefault() {
        let manager = makeManager()
        manager.showVariableRefreshRate = false
        manager.refreshDisplayList()
        guard let rate = manager.availableRefreshRates.first else { return }
        let label = manager.refreshRateLabel(for: rate)
        #expect(label.contains("Hz"))
        #expect(!label.contains("Variable"))
    }

    @Test func refreshRateLabelVariableMode() {
        let manager = makeManager()
        manager.showVariableRefreshRate = true
        manager.refreshDisplayList()
        guard let rate = manager.availableRefreshRates.first else { return }
        let label = manager.refreshRateLabel(for: rate)
        #expect(label.contains("Hz"))
        if manager.allModeOptions.contains(where: { $0.isVariableRate }) {
            #expect(label.contains("Variable"))
        }
    }

    // MARK: - Show All Resolutions Toggle

    @Test func showAllResolutionsIncreasesOrMaintainsModeCount() {
        let manager = makeManager()
        manager.refreshDisplayList()
        let standardCount = manager.availableResolutions.count
        manager.showAllResolutions = true
        let allCount = manager.availableResolutions.count
        #expect(allCount >= standardCount)
    }

    // MARK: - Mode Deduplication

    @Test func noDuplicateResolutionRefreshRatePairs() {
        let manager = makeManager()
        manager.refreshDisplayList()
        var seen = Set<String>()
        for mode in manager.allModeOptions {
            let key = "\(mode.width)x\(mode.height)@\(mode.refreshRate)@\(mode.isHiDPI)"
            #expect(seen.insert(key).inserted, "Duplicate mode: \(key)")
        }
    }

    // MARK: - HiDPI Detection

    @Test func isRetinaDisplayConsistentWithModes() {
        let manager = makeManager()
        manager.refreshDisplayList()
        let hasHiDPI = manager.allModeOptions.contains(where: \.isHiDPI)
        #expect(manager.isRetinaDisplay == hasHiDPI)
    }

    // MARK: - Display Info

    @Test func displayInfoMainDisplayPresent() {
        let manager = makeManager()
        manager.refreshDisplayList()
        let mainDisplay = manager.displays.first(where: \.isMain)
        #expect(mainDisplay != nil)
        #expect(!mainDisplay!.name.isEmpty)
    }

    @Test func selectedDisplayIDIsValid() {
        let manager = makeManager()
        manager.refreshDisplayList()
        #expect(manager.displays.contains(where: { $0.id == manager.selectedDisplayID }))
    }
}
