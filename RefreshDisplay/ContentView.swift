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
            actionSection
            Divider()
            logSection
        }
        .frame(width: 460, height: 500)
        .onAppear {
            manager.refreshDisplayList()
            manager.updateCurrentModeDescription()
        }
        .onChange(of: manager.selectedDisplayID) {
            manager.updateCurrentModeDescription()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "display.2")
                .font(.system(size: 36))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("RefreshDisplay")
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
        VStack(spacing: 12) {
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
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    // MARK: - Action

    private var actionSection: some View {
        Button(action: { manager.performRefresh() }) {
            Label("Refresh Display", systemImage: "arrow.triangle.2.circlepath")
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .keyboardShortcut("r", modifiers: .command)
        .disabled(manager.status == .switching)
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
