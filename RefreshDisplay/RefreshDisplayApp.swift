//
//  RefreshDisplayApp.swift
//  RefreshDisplay
//
//  Created by Neill Shazly on 2026-03-23.
//

import SwiftUI

@main
struct RefreshDisplayApp: App {
    @State private var manager = DisplayRefreshManager()

    var body: some Scene {
        WindowGroup {
            ContentView(manager: manager)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
        }

        MenuBarExtra("RefreshDisplay", systemImage: "display.2") {
            Text(manager.currentModeDescription)
                .font(.caption)

            Divider()

            Button("Refresh Display") {
                manager.performRefresh()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(manager.status == .switching)

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
