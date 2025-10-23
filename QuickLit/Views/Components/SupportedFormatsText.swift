//
//  SupportedFormatsText.swift
//  QuickLit
//
//  Created by Matthew Deik on 10/17/25.
//

import SwiftUI

/// Displays supported file formats in a vertically stacked layout
/// Used in file import sections to show users which formats are accepted
struct SupportedFormatsText: View {
    @ObservedObject var settings: AppSettings  // Theme and appearance settings
    
    var body: some View {
        VStack(spacing: 2) {
            // Display each line of supported formats
            ForEach(SupportedFormat.supportedExtensionsDisplayLines, id: \.self) { line in
                Text(line)
                    .font(.subheadline)
                    .foregroundColor(settings.theme.secondaryTextColor)  // Use theme-appropriate color
                    .multilineTextAlignment(.center)  // Center-align for better presentation
            }
        }
    }
}
