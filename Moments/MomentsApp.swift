//
//  MomentsApp.swift
//  Moments
//
//  Created by Phil Stephens on 2/3/2026.
//

import SwiftUI

@main
struct MomentsApp: App {
    @State private var settingsStore = SettingsStore()

    var body: some Scene {
        WindowGroup {
            TimelineView(store: settingsStore)
                .environment(settingsStore)
        }
    }
}
