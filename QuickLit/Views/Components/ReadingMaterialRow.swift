//
//  ReadingMaterialRow.swift
//  QuickLit
//
//  Created by Matthew Deik on 10/17/25.
//

import SwiftUI

/// Displays a single reading material in the list view
/// Shows title, progress, and last read date with proper formatting
struct ReadingMaterialRow: View {
    // MARK: - Properties
    
    let material: ReadingMaterial      // The reading material to display
    @ObservedObject var settings: AppSettings // Theme and appearance settings
    
    var body: some View {
        VStack(alignment: .leading) {
            // Material title (primary information)
            Text(material.title)
                .foregroundColor(settings.theme.textColor)
            
            // Reading progress (words read / total words)
            Text("Progress: \(material.currentPosition)/\(material.wordCount) words")
                .font(.caption)
                .foregroundColor(settings.theme.secondaryTextColor)
            
            // Last read date with relative formatting
            Text("Last read: \(formatDate(material.lastReadDate))")
                .font(.caption2)
                .foregroundColor(settings.theme.secondaryTextColor.opacity(0.7))
        }
    }
    
    // MARK: - Helper Methods
    
    /// Formats date with relative descriptions for recent dates
    /// Shows "Today", "Yesterday", or full date for older dates
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(date) {
            // Format for today: show time only
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return "Today, \(formatter.string(from: date))"
        } else if Calendar.current.isDateInYesterday(date) {
            // Format for yesterday: show time only
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return "Yesterday, \(formatter.string(from: date))"
        } else {
            // Format for older dates: show both date and time
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}
