//
//  AppSettings.swift
//  QuickLit
//
//  Created by Matthew Deik on 8/21/25.
//

import SwiftUI

// MARK: - App Theme

/// Defines the visual theme options for the QuickLit app
/// Supports system, light, dark, and sepia modes with adaptive colors
enum AppTheme: String, CaseIterable {
    case system
    case light
    case dark
    case sepia
    
    /// User-facing display name for each theme
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        case .sepia: return "Sepia"
        }
    }
    
    /// Forces specific color scheme for themes that need it
    /// Returns nil for system theme to respect device settings
    var forcedColorScheme: ColorScheme? {
        switch self {
        case .light, .sepia: return .light   // Sepia also forces light mode
        case .dark:          return .dark
        case .system:        return nil       // Respect system setting
        }
    }
    
    /// Background color for the current theme
    var backgroundColor: Color {
        switch self {
        case .system:
            #if os(iOS)
            return Color(.systemBackground)
            #else
            return Color(NSColor.windowBackgroundColor)
            #endif
        case .light: return .white
        case .dark: return .black
        case .sepia: return Color(red: 0.98, green: 0.95, blue: 0.87) // Warm sepia tone
        }
    }
    
    /// Primary text color for the current theme
    var textColor: Color {
        switch self {
        case .system:
            #if os(iOS)
            return Color(.label)
            #else
            return Color(NSColor.labelColor)
            #endif
        case .light: return .black
        case .dark: return .white
        case .sepia: return Color(red: 0.28, green: 0.22, blue: 0.14) // Dark brown for sepia
        }
    }
    
    /// Secondary text color for less important text
    var secondaryTextColor: Color {
        switch self {
        case .system:
            #if os(iOS)
            return Color(.secondaryLabel)
            #else
            return Color(NSColor.secondaryLabelColor)
            #endif
        case .light: return .gray
        case .dark: return .gray
        case .sepia: return Color(red: 0.45, green: 0.35, blue: 0.25) // Medium brown for sepia
        }
    }
    
    /// Accent color for interactive elements and highlights
    var accentColor: Color {
        switch self {
        case .system: return .blue
        case .light: return .blue
        case .dark: return .blue
        case .sepia: return .brown  // Brown accent for sepia theme
        }
    }
    
    /// Background color for controls like text fields and buttons
    var controlBackground: Color {
        switch self {
        case .system:
            #if os(iOS)
            return Color(.secondarySystemBackground)
            #else
            return Color(NSColor.controlBackgroundColor)
            #endif
        case .light: return Color(white: 0.95)  // Very light gray
        case .dark: return Color(white: 0.15)   // Dark gray
        case .sepia: return Color(red: 0.95, green: 0.90, blue: 0.80) // Light sepia
        }
    }
}

// MARK: - App Settings

/// Manages all user-configurable settings for the QuickLit app
/// Uses @AppStorage for persistence and @Published for SwiftUI updates
class AppSettings: ObservableObject {
    // MARK: - Default Values
    
    /// Default values for all settings - used for restoration
    private struct Defaults {
        static let readingSpeed: Double = 300
        static let peripheralCharLimit: Int = 12
        static let wordNavigationCount: Int = 1
        static let textSize: Double = 24
        static let selectedFont: String = "System"
        static let textWeight: Double = 300
        static let peripheralBrightness: Double = 0.7
        static let verticalReading: Bool = false
        static let theme: AppTheme = .system
        
        // iOS-only defaults
        #if os(iOS)
        static let autoHideUI: Bool = true
        #endif
        
        // System blue color components
        #if os(iOS)
        static let highlightColorRed: Double = 0.0
        static let highlightColorGreen: Double = 0.478
        static let highlightColorBlue: Double = 1.0
        #else
        static let highlightColorRed: Double = 0.0
        static let highlightColorGreen: Double = 0.478
        static let highlightColorBlue: Double = 1.0
        #endif
    }
    
    // MARK: - Persisted Settings
    
    /// Reading speed in words per minute (WPM)
    @AppStorage("readingSpeed") var readingSpeed: Double = Defaults.readingSpeed
    
    /// Maximum characters allowed in peripheral (non-center) words
    @AppStorage("peripheralCharLimit") var peripheralCharLimit: Int = Defaults.peripheralCharLimit
    
    /// Number of words to skip when using navigation controls
    @AppStorage("wordNavigationCount") var wordNavigationCount: Int = Defaults.wordNavigationCount
    
    /// Base font size for reading text
    @AppStorage("textSize") var textSize: Double = Defaults.textSize
    
    /// Selected font family name
    @AppStorage("selectedFont") var selectedFont: String = Defaults.selectedFont
    
    /// Font weight value (100-900 scale)
    @AppStorage("textWeight") var textWeight: Double = Defaults.textWeight
    
    /// Brightness/dim level for peripheral words
    @AppStorage("peripheralBrightness") var peripheralBrightness: Double = Defaults.peripheralBrightness
    
    /// Whether to display words vertically instead of horizontally
    @AppStorage("verticalReading") var verticalReading: Bool = Defaults.verticalReading
    
    /// Current app theme
    @AppStorage("theme") var theme: AppTheme = Defaults.theme
    
    // MARK: - iOS-Only Settings
    
    #if os(iOS)
    /// Whether to automatically hide UI elements while reading (iOS only)
    @AppStorage("autoHideUI") var autoHideUI: Bool = Defaults.autoHideUI
    #endif
    
    // MARK: - Color Management
    
    /// Storage for highlight color components (persisted separately)
    @AppStorage("highlightColorRed") private var highlightColorRed: Double = Defaults.highlightColorRed
    @AppStorage("highlightColorGreen") private var highlightColorGreen: Double = Defaults.highlightColorGreen
    @AppStorage("highlightColorBlue") private var highlightColorBlue: Double = Defaults.highlightColorBlue

    /// Computed property for highlight color with getter/setter
    var highlightColor: Color {
        get {
            Color(red: highlightColorRed, green: highlightColorGreen, blue: highlightColorBlue)
        }
        set {
            // Extract RGB components from the color and persist them
            if let components = newValue.cgColor?.components, components.count >= 3 {
                highlightColorRed = Double(components[0])
                highlightColorGreen = Double(components[1])
                highlightColorBlue = Double(components[2])
                objectWillChange.send() // Notify SwiftUI of changes
            }
        }
    }
    
    
    // MARK: - Default Restoration
    
    /// Restores all settings to their default values
    func restoreDefaults() {
        // Restore reading settings
        readingSpeed = Defaults.readingSpeed
        peripheralCharLimit = Defaults.peripheralCharLimit
        wordNavigationCount = Defaults.wordNavigationCount
        verticalReading = Defaults.verticalReading
        
        // Restore appearance settings
        textSize = Defaults.textSize
        selectedFont = Defaults.selectedFont
        textWeight = Defaults.textWeight
        peripheralBrightness = Defaults.peripheralBrightness
        theme = Defaults.theme
        
        // Restore iOS-only settings
        #if os(iOS)
        autoHideUI = Defaults.autoHideUI
        #endif
        
        // Restore highlight color to system default
        setToSystemBlue()
        
        // Notify observers that all settings have changed
        objectWillChange.send()
    }
    
    /// Sets the highlight color to the appropriate system blue for the current platform
    private func setToSystemBlue() {
        highlightColorRed = Defaults.highlightColorRed
        highlightColorGreen = Defaults.highlightColorGreen
        highlightColorBlue = Defaults.highlightColorBlue
        objectWillChange.send()
    }
    
    /// Resets the highlight color to the system default
    func resetHighlightColorToSystem() {
        setToSystemBlue()
    }
    
    // MARK: - Font Management
    
    /// Available font families for the user to choose from
    static let availableFonts = ["System", "Avenir", "Helvetica", "Georgia", "Menlo"]
    
    /// Converts numeric weight value to SwiftUI Font.Weight
    var fontWeight: Font.Weight {
        switch textWeight {
        case 100: return .ultraLight
        case 200: return .thin
        case 300: return .light
        case 400: return .regular
        case 500: return .medium
        case 600: return .semibold
        case 700: return .bold
        case 800: return .heavy
        case 900: return .black
        default: return .regular
        }
    }
    
    /// Computes the actual font to use based on selected font family and size
    var actualFont: Font {
        if selectedFont == "System" {
            return .system(size: CGFloat(textSize), weight: fontWeight)
        } else {
            return .custom(selectedFont, size: CGFloat(textSize))
        }
    }
    
    /// Larger font for the center word in RSVP display
    var centerFont: Font {
        if selectedFont == "System" {
            return .system(size: CGFloat(textSize * 1.5), weight: .bold)
        } else {
            return .custom(selectedFont, size: CGFloat(textSize * 1.5))
        }
    }
}
