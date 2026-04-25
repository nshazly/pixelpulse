//
//  SettingsView.swift
//  PixelPulse
//
//  Created by Neill Shazly on 2026-04-23.
//

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Bindable var manager: DisplayRefreshManager
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            Toggle("Variable Refresh Rate", isOn: $manager.showVariableRefreshRate)
                .help("Show variable refresh rate labels for displays that report dynamic rates (e.g. ProMotion)")

            Toggle("Show All Resolutions", isOn: $manager.showAllResolutions)
                .help("Include non-Retina and low-resolution display modes beyond the standard scaled options")
        }
        .formStyle(.grouped)
        .frame(width: 320, height: 180)
    }
}

#Preview {
    SettingsView(manager: DisplayRefreshManager())
}
