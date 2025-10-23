//
//  BottomButtonArea.swift
//  QuickLit
//
//  Created by Matthew Deik on 10/17/25.
//

import SwiftUI

/// Bottom button area for the Add Material view
/// Provides Cancel and Add actions with proper state management
struct BottomButtonArea: View {
    // MARK: - Bindings
    
    @Binding var showingAdder: Bool      // Controls sheet visibility
    @Binding var inputMethod: InputMethod // Text vs File input mode
    @Binding var importedFiles: [ImportedFile] // Files selected for import
    @Binding var newContent: String      // Text content for manual input
    @Binding var newTitle: String        // Title for manual input
    @Binding var isUnsupportedFile: Bool // Error state for file validation
    
    // MARK: - Dependencies
    
    @ObservedObject var settings: AppSettings // Theme and appearance settings
    
    // MARK: - Callbacks
    
    let onAddNewContent: () -> Void  // Handler for adding text content
    let onImportFiles: () -> Void    // Handler for importing files
    
    var body: some View {
        VStack(spacing: 0) {
            // Divider separating content from buttons
            Divider()
                .background(settings.theme.secondaryTextColor.opacity(0.3))
            
            // Horizontal stack for Cancel and Add buttons
            HStack {
                // Cancel button - dismisses sheet and resets state
                Button("Cancel") {
                    showingAdder = false
                    newContent = ""
                    newTitle = ""
                    importedFiles.removeAll()
                    inputMethod = .text
                    isUnsupportedFile = false
                }
                .foregroundColor(settings.theme.secondaryTextColor)
                .padding(.vertical, 16)
                
                Spacer()
                
                // Add button - triggers appropriate action based on input method
                Button("Add") {
                    if inputMethod == .text {
                        onAddNewContent()
                    } else if !importedFiles.isEmpty {
                        onImportFiles()
                    }
                    showingAdder = false
                }
                // Disable if required fields are empty
                .disabled(
                    (inputMethod == .text && (newContent.isEmpty || newTitle.isEmpty)) ||
                    (inputMethod == .file && importedFiles.isEmpty)
                )
                .foregroundColor(settings.theme.accentColor)
                .padding(.vertical, 16)
            }
            .padding(.horizontal)
            .background(settings.theme.backgroundColor)
        }
        .background(settings.theme.backgroundColor)
    }
}
