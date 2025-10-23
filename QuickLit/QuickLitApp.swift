//
//  QuickLitApp.swift
//  QuickLit
//
//  Created by Matthew Deik on 8/19/25.
//

import SwiftUI
import SwiftData

/// Main app entry point and configuration
/// Sets up the SwiftData container and global app settings
@main
struct QuickLitApp: App {
    @StateObject private var settings = AppSettings()   // Global app settings and theme management
    let container: ModelContainer  // SwiftData persistent container
    
    init() {
        do {
            // Configure SwiftData with persistent storage
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            container = try ModelContainer(for: ReadingMaterial.self, configurations: config)
            print("SwiftData container initialized successfully")
        } catch {
            fatalError("Failed to configure SwiftData container: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)                    // Inject settings to entire app
                .preferredColorScheme(settings.theme.forcedColorScheme) // Apply theme color scheme
        }
        .modelContainer(container)  // Provide SwiftData container to views
    }
}
