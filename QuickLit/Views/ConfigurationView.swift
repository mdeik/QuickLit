//
//  ConfigurationView.swift
//
//  Created by Matthew Deik on 8/21/25.
//

import SwiftUI

// MARK: - Configuration View

/// Comprehensive settings view for customizing reading experience and appearance
/// Provides platform-appropriate interfaces for iOS and macOS
struct ConfigurationView: View {
    @ObservedObject var settings: AppSettings  // App settings model
    @Environment(\.dismiss) private var dismiss  // Environment dismissal handler
    @State private var navigationID = UUID() // Force refresh when theme changes
    @State private var showingResetAlert = false // Reset confirmation alert
    
    // MARK: - Typography Constants
    
    /// Standard font for configuration text
    private var configFont: Font {
        .system(.body, design: .default, weight: .regular)
    }
    
    /// Font for section headers
    private var sectionHeaderFont: Font {
        .system(.headline, design: .default, weight: .semibold)
    }

    var body: some View {
        // Platform-specific implementations
        #if os(macOS)
        macConfigurationView
        #else
        iosConfigurationView
        #endif
    }
    
    // MARK: - iOS Implementation
    
    /// iOS-optimized settings using Form and NavigationView
    private var iosConfigurationView: some View {
        NavigationView {
            ZStack {
                // Full background color
                settings.theme.backgroundColor
                    .ignoresSafeArea()
                
                // Settings form
                Form {
                    readingSettingsSection
                    appearanceSettingsSection
                    resetDefaultsSection
                }
                .scrollContentBackground(.hidden)  // Hide default form background
                .background(settings.theme.backgroundColor)
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)  // Compact navigation bar
            #endif
            .toolbar {
                // Done button for dismissal
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(settings.theme.accentColor)
                        .font(configFont)
                        .accessibilityLabel("Done with settings")
                }
            }
        }
        #if os(iOS)
        .navigationViewStyle(.stack)  // Standard iOS navigation style
        #endif
        .background(settings.theme.backgroundColor)
        .id(navigationID)  // Force refresh on theme change
        .onChange(of: settings.theme) { _, _ in
            navigationID = UUID()  // Regenerate ID to force view refresh
        }
        .alert("Reset to Defaults", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settings.restoreDefaults()
            }
        } message: {
            Text("This will reset all settings to their default values. This action cannot be undone.")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Reading settings")
    }
    
    // MARK: - macOS Implementation
    
    /// macOS-optimized settings with custom layout and larger controls
    private var macConfigurationView: some View {
        VStack(spacing: 0) {
            // Header with title and done button
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(settings.theme.textColor)
                
                Spacer()
                
                Button("Done") { dismiss() }
                    .foregroundColor(settings.theme.accentColor)
                    .accessibilityLabel("Done with settings")
            }
            .padding()
            .background(settings.theme.controlBackground)
            
            // Scrollable settings content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Reading Settings section
                    readingSettingsMacSection
                    
                    // Appearance Settings section
                    appearanceSettingsMacSection
                    
                    // Reset Defaults section
                    resetDefaultsMacSection
                }
                .padding()
            }
        }
        .frame(minWidth: 400, minHeight: 500)  // macOS-appropriate sizing
        .background(settings.theme.backgroundColor)
        .id(navigationID)
        .onChange(of: settings.theme) { _, _ in
            navigationID = UUID()  // Force refresh on theme change
        }
        .alert("Reset to Defaults", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settings.restoreDefaults()
            }
        } message: {
            Text("This will reset all settings to their default values. This action cannot be undone.")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Reading settings configuration")
    }
    
    // MARK: - Reset Defaults Sections
    
    /// iOS-specific reset defaults section
    private var resetDefaultsSection: some View {
        Section {
            Button("Reset to Defaults") {
                showingResetAlert = true
            }
            .foregroundColor(.red)
            .font(configFont)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityLabel("Reset all settings to default values")
            .accessibilityHint("Double tap to confirm reset")
        }
        .listRowBackground(settings.theme.controlBackground)
    }
    
    /// macOS-specific reset defaults section
    private var resetDefaultsMacSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reset Settings")
                .font(sectionHeaderFont)
                .foregroundColor(settings.theme.textColor)
                .accessibilityAddTraits(.isHeader)
            
            VStack(alignment: .center, spacing: 8) {
                Text("This will restore all settings to their original default values.")
                    .font(.system(.caption, design: .default))
                    .foregroundColor(settings.theme.secondaryTextColor)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Warning: This will restore all settings to original defaults")
                
                Button("Reset to Defaults") {
                    showingResetAlert = true
                }
                .foregroundColor(.red)
                .font(configFont)
                .accessibilityLabel("Reset all settings to default values")
                .accessibilityHint("Double tap to confirm reset")
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(settings.theme.controlBackground)
        .cornerRadius(8)
    }
    
    // MARK: - macOS Reading Settings Section
    
    /// macOS-specific reading settings layout
    private var readingSettingsMacSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reading Settings")
                .font(sectionHeaderFont)
                .foregroundColor(settings.theme.textColor)
                .accessibilityAddTraits(.isHeader)  // VoiceOver header announcement
            
            VStack(alignment: .leading, spacing: 16) {
                // Reading speed slider
                settingRow(
                    title: "Reading Speed: \(Int(settings.readingSpeed)) WPM",
                    value: $settings.readingSpeed,
                    range: 100...1200,
                    step: 25,
                    accessibilityLabel: "Reading speed",
                    accessibilityValue: "\(Int(settings.readingSpeed)) words per minute"
                )
                
                // Word navigation stepper
                Stepper("Word Navigation: \t\(settings.wordNavigationCount)",
                       value: $settings.wordNavigationCount, in: 1...10)
                    .accessibilityLabel("Word navigation count")
                    .accessibilityValue("\(settings.wordNavigationCount) words")
                
                // Vertical reading toggle
                Toggle("Vertical Reading", isOn: $settings.verticalReading)
                    .tint(settings.theme.accentColor)
                    .foregroundColor(settings.theme.textColor)
                    .font(configFont)
                    .accessibilityLabel("Vertical reading mode")
                    .accessibilityValue(settings.verticalReading ? "On" : "Off")
            }
        }
        .padding()
        .background(settings.theme.controlBackground)
        .cornerRadius(8)
    }
    
    // MARK: - macOS Appearance Settings Section
    
    /// macOS-specific appearance settings layout
    private var appearanceSettingsMacSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(sectionHeaderFont)
                .foregroundColor(settings.theme.textColor)
                .accessibilityAddTraits(.isHeader)
            
            VStack(alignment: .leading, spacing: 16) {
                // Text size slider
                settingRow(
                    title: "Text Size: \(Int(settings.textSize))",
                    value: $settings.textSize,
                    range: 16...40,
                    step: 2,
                    accessibilityLabel: "Text size",
                    accessibilityValue: "\(Int(settings.textSize)) points"
                )
                
                // Font selection picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Font")
                        .foregroundColor(settings.theme.textColor)
                        .font(configFont)
                        .accessibilityLabel("Font selection")
                    
                    Picker("Font", selection: $settings.selectedFont) {
                        ForEach(AppSettings.availableFonts, id: \.self) { font in
                            Text(font)
                                .tag(font)
                                .foregroundColor(settings.theme.textColor)
                                .font(configFont)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .accessibilityLabel("Selected font: \(settings.selectedFont)")
                }
                
                // Font weight slider
                settingRow(
                    title: "Font Weight: \(Int(settings.textWeight))",
                    value: $settings.textWeight,
                    range: 100...900,
                    step: 100,
                    accessibilityLabel: "Font weight",
                    accessibilityValue: "\(Int(settings.textWeight))"
                )
                
                // Peripheral brightness slider
                settingRow(
                    title: "Peripheral Brightness: \(Int(settings.peripheralBrightness * 100))%",
                    value: $settings.peripheralBrightness,
                    range: 0.1...1.0,
                    step: 0.1,
                    accessibilityLabel: "Peripheral brightness",
                    accessibilityValue: "\(Int(settings.peripheralBrightness * 100)) percent"
                )
                
                // Highlight color picker
                HStack {
                    Text("Highlight Color")
                        .foregroundColor(settings.theme.textColor)
                        .font(configFont)
                        .accessibilityLabel("Highlight color")
                    
                    Spacer()
                    
                    ColorPicker("", selection: $settings.highlightColor)
                        .labelsHidden()
                        .accessibilityLabel("Color picker for highlight color")
                }
            }
        }
        .padding()
        .background(settings.theme.controlBackground)
        .cornerRadius(8)
    }
    
    // MARK: - Reusable Components
    
    /// Creates a consistent slider-based setting row for macOS
    private func settingRow(title: String, value: Binding<Double>, range: ClosedRange<Double>,
                           step: Double, accessibilityLabel: String, accessibilityValue: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundColor(settings.theme.textColor)
                .font(configFont)
                .accessibilityHidden(true)  // Hide from VoiceOver (handled by slider)
            
            Slider(value: value, in: range, step: step)
                .tint(settings.theme.accentColor)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityValue(accessibilityValue)
                .accessibilityAdjustableAction { direction in
                    // Handle VoiceOver adjustment gestures
                    let currentValue = value.wrappedValue
                    let newValue: Double
                    
                    switch direction {
                    case .increment:
                        newValue = min(currentValue + step, range.upperBound)
                    case .decrement:
                        newValue = max(currentValue - step, range.lowerBound)
                    @unknown default:
                        newValue = currentValue
                    }
                    
                    value.wrappedValue = newValue
                }
        }
    }
    
    // MARK: - iOS Form Sections
    
    /// iOS reading settings section for Form layout
    private var readingSettingsSection: some View {
        Section {
            // Reading speed slider
            VStack(alignment: .leading, spacing: 12) {
                Text("Reading Speed: \(Int(settings.readingSpeed)) WPM")
                    .foregroundColor(settings.theme.textColor)
                    .font(configFont)
                    .accessibilityHidden(true)
                
                Slider(value: $settings.readingSpeed, in: 100...1200, step: 25)
                    .tint(settings.theme.accentColor)
                    .accessibilityLabel("Reading speed")
                    .accessibilityValue("\(Int(settings.readingSpeed)) words per minute")
                    .accessibilityAdjustableAction { direction in
                        let currentValue = settings.readingSpeed
                        let newValue: Double
                        
                        switch direction {
                        case .increment:
                            newValue = min(currentValue + 25, 600)
                        case .decrement:
                            newValue = max(currentValue - 25, 50)
                        @unknown default:
                            newValue = currentValue
                        }
                        
                        settings.readingSpeed = newValue
                    }
            }
            .padding(.vertical, 4)
            
            // Word navigation stepper
            Stepper("Word Navigation: \(settings.wordNavigationCount)",
                   value: $settings.wordNavigationCount, in: 1...10)
            .font(configFont)
            .foregroundColor(settings.theme.textColor)
            .accessibilityLabel("Word navigation count")
            .accessibilityValue("\(settings.wordNavigationCount) words")
            
            // Vertical reading toggle
            Toggle("Vertical Reading", isOn: $settings.verticalReading)
                .tint(settings.theme.accentColor)
                .foregroundColor(settings.theme.textColor)
                .font(configFont)
                .accessibilityLabel("Vertical reading mode")
                .accessibilityValue(settings.verticalReading ? "On" : "Off")
            
            // iOS-only: Auto-hide UI toggle
            #if os(iOS)
            Toggle("Auto-Hide UI", isOn: $settings.autoHideUI)
                .tint(settings.theme.accentColor)
                .foregroundColor(settings.theme.textColor)
                .font(configFont)
                .accessibilityLabel("Auto hide user interface")
                .accessibilityValue(settings.autoHideUI ? "On" : "Off")
            #endif
            
        } header: {
            Text("Reading Settings")
                .foregroundColor(settings.theme.textColor)
                .font(sectionHeaderFont)
                .accessibilityAddTraits(.isHeader)
        }.listRowBackground(settings.theme.controlBackground)
    }
    
    /// iOS appearance settings section for Form layout
    private var appearanceSettingsSection: some View {
        Section {
            // Theme selection picker
            Picker("Theme", selection: $settings.theme) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Text(theme.displayName)
                        .tag(theme)
                        .foregroundColor(settings.theme.textColor)
                        .font(configFont)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.vertical, 4)
            .accessibilityLabel("Theme selection")
            .accessibilityValue(settings.theme.displayName)
            
            // Text size slider
            VStack(alignment: .leading, spacing: 12) {
                Text("Text Size: \(Int(settings.textSize))")
                    .foregroundColor(settings.theme.textColor)
                    .font(configFont)
                    .accessibilityHidden(true)
                
                Slider(value: $settings.textSize, in: 16...40, step: 2)
                    .tint(settings.theme.accentColor)
                    .accessibilityLabel("Text size")
                    .accessibilityValue("\(Int(settings.textSize)) points")
                    .accessibilityAdjustableAction { direction in
                        let currentValue = settings.textSize
                        let newValue: Double
                        
                        switch direction {
                        case .increment:
                            newValue = min(currentValue + 2, 40)
                        case .decrement:
                            newValue = max(currentValue - 2, 16)
                        @unknown default:
                            newValue = currentValue
                        }
                        
                        settings.textSize = newValue
                    }
            }
            .padding(.vertical, 4)
            
            // Font selection picker
            Picker("Font", selection: $settings.selectedFont) {
                ForEach(AppSettings.availableFonts, id: \.self) { font in
                    Text(font)
                        .tag(font)
                        .foregroundColor(settings.theme.textColor)
                        .font(configFont)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .foregroundColor(settings.theme.textColor)
            .accentColor(settings.theme.accentColor)
            .padding(.vertical, 4)
            .accessibilityLabel("Font selection")
            .accessibilityValue("Selected font: \(settings.selectedFont)")
            
            // Font weight slider
            VStack(alignment: .leading, spacing: 12) {
                Text("Font Weight: \(Int(settings.textWeight))")
                    .foregroundColor(settings.theme.textColor)
                    .font(configFont)
                    .accessibilityHidden(true)
                
                Slider(value: $settings.textWeight, in: 100...900, step: 100)
                    .tint(settings.theme.accentColor)
                    .accessibilityLabel("Font weight")
                    .accessibilityValue("\(Int(settings.textWeight))")
                    .accessibilityAdjustableAction { direction in
                        let currentValue = settings.textWeight
                        let newValue: Double
                        
                        switch direction {
                        case .increment:
                            newValue = min(currentValue + 100, 900)
                        case .decrement:
                            newValue = max(currentValue - 100, 100)
                        @unknown default:
                            newValue = currentValue
                        }
                        
                        settings.textWeight = newValue
                    }
            }
            .padding(.vertical, 4)
            
            // Peripheral brightness slider
            VStack(alignment: .leading, spacing: 12) {
                Text("Peripheral Brightness: \(Int(settings.peripheralBrightness * 100))%")
                    .foregroundColor(settings.theme.textColor)
                    .font(configFont)
                    .accessibilityHidden(true)
                
                Slider(value: $settings.peripheralBrightness, in: 0.1...1.0, step: 0.1)
                    .tint(settings.theme.accentColor)
                    .accessibilityLabel("Peripheral brightness")
                    .accessibilityValue("\(Int(settings.peripheralBrightness * 100)) percent")
                    .accessibilityAdjustableAction { direction in
                        let currentValue = settings.peripheralBrightness
                        let newValue: Double
                        
                        switch direction {
                        case .increment:
                            newValue = min(currentValue + 0.1, 1.0)
                        case .decrement:
                            newValue = max(currentValue - 0.1, 0.1)
                        @unknown default:
                            newValue = currentValue
                        }
                        
                        settings.peripheralBrightness = newValue
                    }
            }
            .padding(.vertical, 4)
            
            // Highlight color picker
            ColorPicker("Highlight Color", selection: $settings.highlightColor)
                .foregroundColor(settings.theme.textColor)
                .font(configFont)
                .accessibilityLabel("Highlight color picker")
        } header: {
            Text("Appearance")
                .foregroundColor(settings.theme.textColor)
                .font(sectionHeaderFont)
                .accessibilityAddTraits(.isHeader)
        }
        .listRowBackground(settings.theme.controlBackground)
    }
}
