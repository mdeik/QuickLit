//
//  StatRow.swift
//  QuickLit
//
//  Created by Matthew Deik on 8/21/25.
//

import SwiftUI

/// A reusable row component for displaying statistics in a consistent format
/// Used in settings and statistics views to show label-value pairs
struct StatRow: View {
    let label: String  // The label text (e.g., "Reading Speed")
    let value: String  // The value text (e.g., "300 WPM")
    
    var body: some View {
        HStack {
            Text(label + ":")
                .fontWeight(.medium)  // Emphasize the label
            Spacer()  // Push value to the right
            Text(value)
                .foregroundColor(.secondary)  // Dim the value for visual hierarchy
        }
    }
}
