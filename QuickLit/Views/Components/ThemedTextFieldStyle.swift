//
//  ThemedTextFieldStyle.swift
//  QuickLit
//
//  Created by Matthew Deik on 10/17/25.
//

import SwiftUI

/// A custom text field style that adapts to the app's current theme
/// Provides consistent styling for text inputs throughout the application
struct ThemedTextFieldStyle: TextFieldStyle {
    @ObservedObject var settings: AppSettings  // Theme and appearance settings
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)   // Horizontal padding for text comfort
            .padding(.vertical, 12)     // Vertical padding for touch targets
            .background(settings.theme.controlBackground)  // Theme-appropriate background
            .foregroundColor(settings.theme.textColor)     // Theme-appropriate text color
            .cornerRadius(8)  // Rounded corners for modern appearance
            .overlay(
                // Subtle border for definition
                RoundedRectangle(cornerRadius: 8)
                    .stroke(settings.theme.secondaryTextColor.opacity(0.3), lineWidth: 1)
            )
    }
}
