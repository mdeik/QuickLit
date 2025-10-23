//
//  StatsView.swift
//  QuickLit
//
//  Created by Matthew Deik on 8/21/25.
//

import SwiftUI

// MARK: - Stats View

/// Displays reading statistics and progress information in a compact modal
/// Shows key metrics like progress, reading speed, and estimated time remaining
struct StatsView: View {
    let material: ReadingMaterial           // The reading material being analyzed
    @ObservedObject var viewModel: ReadingViewModel  // Reading state and settings
    @Environment(\.dismiss) private var dismiss      // Sheet dismissal handler
    
    // MARK: - Computed Properties
    
    /// Calculates reading progress as a percentage (0.0 to 1.0)
    var progress: Double {
        guard viewModel.totalWords > 0 else { return 0 }
        return Double(viewModel.currentPosition) / Double(viewModel.totalWords)
    }
    
    /// Calculates and formats estimated time remaining based on reading speed
    var estimatedTimeRemaining: String {
        guard viewModel.settings.readingSpeed > 0 else { return "N/A" }
        let wordsRemaining = viewModel.totalWords - viewModel.currentPosition
        let minutes = Double(wordsRemaining) / viewModel.settings.readingSpeed
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]  // Show minutes and seconds
        formatter.unitsStyle = .abbreviated          // "5m 30s" format
        
        return formatter.string(from: minutes * 60) ?? "N/A"  // Convert to seconds
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Reading Statistics")
                .font(.headline)
                .padding(.top)
            
            // Statistics rows
            VStack(alignment: .leading, spacing: 10) {
                StatRow(label: "Title", value: material.title)
                StatRow(label: "Total Words", value: "\(viewModel.totalWords)")
                StatRow(label: "Current Position", value: "\(viewModel.currentPosition + 1)")  // 1-based for user display
                StatRow(label: "Progress", value: "\(Int(progress * 100))%")  // Percentage format
                StatRow(label: "Reading Speed", value: "\(Int(viewModel.settings.readingSpeed)) WPM")
                StatRow(label: "Estimated Time Left", value: estimatedTimeRemaining)
                StatRow(label: "Reading Mode", value: viewModel.settings.verticalReading ? "Vertical" : "Horizontal")
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Dismiss button
            Button("Done") {
                dismiss()
            }
            .padding(.bottom)
        }
        .frame(width: 300, height: 350)  // Fixed size for modal presentation
    }
}
