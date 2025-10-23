//
//  AppSettingsTests.swift
//  QuickLit
//
//  Created by Matthew Deik on 10/18/25.
//


//
//  AppSettingsTests.swift
//  QuickLitTests
//
//  Created by Matthew Deik on 8/19/25.
//

import Testing
import SwiftUI
@testable import QuickLit

@Suite("AppSettings Tests")
struct AppSettingsTests {
    
    @Test("AppSettings initializes with default values")
    func testDefaultInitialization() {
        let settings = AppSettings()
        settings.restoreDefaults()
        #expect(settings.readingSpeed == 300)
        #expect(settings.peripheralCharLimit == 12)
        #expect(settings.wordNavigationCount == 1)
        #expect(settings.textSize == 24)
        #expect(settings.selectedFont == "System")
        #expect(settings.textWeight == 300.0)
        #expect(settings.peripheralBrightness == 0.7)
        #expect(settings.verticalReading == false)
        #expect(settings.theme == .system)
    }
    
    @Test("Theme properties return correct values")
    func testThemeProperties() {
        let settings = AppSettings()
        
        // Test each theme
        let themes: [AppTheme] = [.system, .light, .dark, .sepia]
        
        for theme in themes {
            settings.theme = theme
            
            // Basic properties should not crash and return non-clear colors
            #expect(settings.theme.backgroundColor != .clear)
            #expect(settings.theme.textColor != .clear)
            #expect(settings.theme.secondaryTextColor != .clear)
            #expect(settings.theme.accentColor != .clear)
            #expect(settings.theme.controlBackground != .clear)
            
            // Display name should not be empty
            #expect(!settings.theme.displayName.isEmpty)
        }
    }
    
    @Test("Font weight conversion")
    func testFontWeightConversion() {
        let settings = AppSettings()
        
        let testCases: [(Double, Font.Weight)] = [
            (100, .ultraLight),
            (200, .thin),
            (300, .light),
            (400, .regular),
            (500, .medium),
            (600, .semibold),
            (700, .bold),
            (800, .heavy),
            (900, .black),
            (123, .regular), // Default case for unknown values
        ]
        
        for (weightValue, expectedWeight) in testCases {
            settings.textWeight = weightValue
            #expect(settings.fontWeight == expectedWeight,
                   "Expected \(expectedWeight) for weight \(weightValue), got \(settings.fontWeight)")
        }
    }
    
    @Test("Available fonts list contains expected fonts")
    func testAvailableFonts() {
        let availableFonts = AppSettings.availableFonts
        #expect(!availableFonts.isEmpty)
        #expect(availableFonts.contains("System"))
        #expect(availableFonts.contains("Avenir"))
        #expect(availableFonts.contains("Helvetica"))
        #expect(availableFonts.contains("Georgia"))
        #expect(availableFonts.contains("Menlo"))
    }
    
    @Test("Highlight color management")
    func testHighlightColor() {
        let settings = AppSettings()
        settings.restoreDefaults()
        // Should have a default color
        let defaultColor = settings.highlightColor
        #expect(defaultColor != .clear)
        
        // Should be able to set a new color
        let newColor = Color(red: 1.0, green: 0.75, blue: 0.0) // Gold
        settings.highlightColor = newColor
        #expect(settings.highlightColor == newColor)
        
        // Should be able to reset to system
        settings.resetHighlightColorToSystem()
        #expect(settings.highlightColor != newColor)
    }
    
    @Test("Settings persistence through property wrappers")
    func testSettingsPersistence() async {
        // This tests that @AppStorage properties work correctly
        // Note: In practice, these would persist between app runs, but in tests
        // they might use in-memory storage or be reset
        
        let settings = AppSettings()
        
        // Change some values
        settings.readingSpeed = 400
        settings.textSize = 30
        settings.verticalReading = true
        
        #expect(settings.readingSpeed == 400)
        #expect(settings.textSize == 30)
        #expect(settings.verticalReading == true)
    }
}
