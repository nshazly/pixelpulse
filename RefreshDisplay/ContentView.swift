//
//  ContentView.swift
//  RefreshDisplay
//
//  Created by Neill Shazly on 2026-03-23.
//

import SwiftUI

struct ContentView: View {
    @Bindable var manager: DisplayRefreshManager

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            infoSection
            targetSection
            actionSection
            Divider()
            logSection
        }
        .frame(width: 460, height: 580)
        .onAppear {
            manager.refreshDisplayList()
            manager.updateCurrentModeDescription()
        }
        .onChange(of: manager.selectedDisplayID) {
            manager.reloadModes()
            manager.updateCurrentModeDescription()
        }
        .onChange(of: manager.selectedResolution) {
            if let rates = Optional(manager.availableRefreshRates),
               let current = manager.selectedRefreshRate,
               !rates.contains(current) {
                manager.selectedRefreshRate = rates.first
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "display.2")
                .font(.system(size: 36))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("PixelPulse")
                    .font(.title2.bold())
                Text("Fix Samsung Odyssey G9 refresh rate sync")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    // MARK: - Info

    private var infoSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Display")
                        .fontWeight(.medium)
                    Spacer()
                    Picker("", selection: $manager.selectedDisplayID) {
                        ForEach(manager.displays) { display in
                            Text(display.name).tag(display.id)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 220)
                }

                HStack {
                    Text("Current Mode")
                        .fontWeight(.medium)
                    Spacer()
                    Text(manager.currentModeDescription)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                HStack {
                    Text("Status")
                        .fontWeight(.medium)
                    Spacer()
                    HStack(spacing: 6) {
                        if manager.status == .switching {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Circle()
                            .fill(manager.status.color)
                            .frame(width: 8, height: 8)
                        Text(manager.status.label)
                            .foregroundStyle(manager.status.color)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    // MARK: - Target Mode Selection

    private var targetSection: some View {
        GroupBox("Switch via") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Resolution")
                        .fontWeight(.medium)
                    Spacer()
                    Picker("", selection: $manager.selectedResolution) {
                        ForEach(manager.availableResolutions, id: \.self) { res in
                            Text(res.label).tag(Optional(res))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 180)
                }

                HStack {
                    Text("Refresh Rate")
                        .fontWeight(.medium)
                    Spacer()
                    Picker("", selection: $manager.selectedRefreshRate) {
                        ForEach(manager.availableRefreshRates, id: \.self) { rate in
                            Text(String(format: "%.0f Hz", rate)).tag(Optional(rate))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 180)
                }

                if let target = manager.selectedTargetMode {
                    Text("Will switch to \(target.label), wait 2s, then restore.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Action

    private var actionSection: some View {
        Button(action: { manager.performRefresh() }) {
            Label("Refresh Display", systemImage: "arrow.triangle.2.circlepath")
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .keyboardShortcut("r", modifiers: .command)
        .disabled(manager.status == .switching || manager.selectedTargetMode == nil)
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Log

    private var logSection: some View {
        GroupBox("Log") {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(manager.logEntries.enumerated()), id: \.offset) { index, entry in
                            Text(entry)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .id(index)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                }
                .onChange(of: manager.logEntries.count) {
                    if let last = manager.logEntries.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
        .padding([.horizontal, .bottom])
    }
}

#Preview {
    ContentView(manager: DisplayRefreshManager())
}
