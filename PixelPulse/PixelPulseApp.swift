//
//  PixelPulseApp.swift
//  PixelPulse
//
//  Created by Neill Shazly on 2026-03-23.
//

import SwiftUI

@main
struct PixelPulseApp: App {
    @State private var manager = DisplayRefreshManager()

    var body: some Scene {
        WindowGroup {
            ContentView(manager: manager)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView(manager: manager)
        }

        MenuBarExtra("PixelPulse", systemImage: "display.2") {
            Text(manager.currentModeDescription)
                .font(.caption)

            Divider()

            Button("Refresh Display") {
                manager.performRefresh()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(manager.status == .switching)

            Divider()

            Menu("Switch via...") {
                ForEach(manager.modesGroupedByResolution, id: \.resolution) { group in
                    Section(group.resolution.label) {
                        ForEach(group.modes) { mode in
                            Button(String(format: "%.0f Hz", mode.refreshRate)) {
                                manager.performRefreshWith(targetModeOption: mode)
                            }
                            .disabled(manager.status == .switching)
                        }
                    }
                }
            }

            if manager.status == .switching {
                Text("Switching...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
