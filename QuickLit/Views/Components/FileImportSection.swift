//
//  FileImportSection.swift
//  QuickLit
//
//  Created by Matthew Deik on 10/17/25.
//

import SwiftUI
import UniformTypeIdentifiers

/// File import section for the Add Material view
/// Handles drag & drop, file selection, and displays selected files
struct FileImportSection: View {
    // MARK: - Bindings
    
    @Binding var importedFiles: [ImportedFile]  // List of selected files
    @Binding var isImporting: Bool              // File picker presentation state
    @Binding var isDropTargeted: Bool           // Drag & drop highlight state
    @Binding var isUnsupportedFile: Bool        // Unsupported file type error
    
    // MARK: - Dependencies
    
    @ObservedObject var settings: AppSettings   // Theme and appearance
    
    // MARK: - Callbacks
    
    let onRemoveFile: (ImportedFile) -> Void    // Remove file from selection
    let onDropFiles: ([NSItemProvider]) -> Bool // Drop handler callback

    var body: some View {
        VStack {
            if !importedFiles.isEmpty {
                // Display selected files in a scrollable list
                selectedFilesView
            } else {
                // Show drop zone when no files are selected
                dropZoneView
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
        .background(settings.theme.backgroundColor)
    }
    
    // MARK: - Selected Files View
    
    /// Displays the list of selected files with remove options
    private var selectedFilesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with file count
            Text("Selected Files (\(importedFiles.count))")
                .font(.headline)
                .foregroundColor(settings.theme.textColor)
            
            // Scrollable list of files
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(importedFiles) { file in
                        HStack {
                            // File info (name, extension, size)
                            VStack(alignment: .leading) {
                                Text(file.name)
                                    .fontWeight(.semibold)
                                    .foregroundColor(settings.theme.textColor)
                                    .lineLimit(1)
                                Text("\(file.extension.uppercased()) · \(formatFileSize(file.size))")
                                    .font(.caption)
                                    .foregroundColor(settings.theme.secondaryTextColor)
                            }
                            Spacer()
                            
                            // Remove file button
                            Button(action: { onRemoveFile(file) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(settings.theme.secondaryTextColor)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(settings.theme.controlBackground)
                        .cornerRadius(8)
                    }
                }
                .padding(1)
            }
            .frame(height: 190)
            .background(settings.theme.controlBackground.opacity(0.3))
            .cornerRadius(8)
            
            // Clear all button
            HStack {
                Spacer()
                Button("Clear All") {
                    importedFiles.removeAll()
                }
                .foregroundColor(.red)
            }
        }
        .padding(.horizontal)
        .background(settings.theme.backgroundColor)
    }
    
    // MARK: - Drop Zone View
    
    /// Shows the file drop zone with instructions and supported formats
    private var dropZoneView: some View {
        ZStack {
            #if os(macOS)
            // Styled background with conditional coloring
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isUnsupportedFile ? Color.red :
                    (isDropTargeted ? settings.theme.accentColor : settings.theme.secondaryTextColor),
                    style: StrokeStyle(lineWidth: 2, dash: [5])
                )
                .background(
                    isUnsupportedFile ? Color.red.opacity(0.1) :
                    (isDropTargeted ? settings.theme.accentColor.opacity(0.1) : settings.theme.controlBackground)
                )
            #endif
            // Content stack with icon and instructions
            VStack(spacing: 12) {
                // Conditional icon based on state
                Image(systemName: isUnsupportedFile ? "xmark.circle" : "doc.badge.plus")
                    .font(.system(size: 40))
                    .foregroundColor(
                        isUnsupportedFile ? .red :
                        (isDropTargeted ? settings.theme.accentColor : settings.theme.secondaryTextColor)
                    )
                
                if isUnsupportedFile {
                    // Error state for unsupported files
                    VStack(spacing: 4) {
                        Text("Unsupported File Type")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text("Please use:")
                            .font(.subheadline)
                            .foregroundColor(settings.theme.secondaryTextColor)
                        SupportedFormatsText(settings: settings)
                    }
                } else {
                    // Normal state with instructions
                    VStack(spacing: 4) {
                        #if os(macOS)
                        Text("Drag & drop files here")
                            .font(.headline)
                            .foregroundColor(settings.theme.textColor)
                        #endif
                        Text("Supported formats:")
                            .font(.subheadline)
                            .foregroundColor(settings.theme.secondaryTextColor)
                        SupportedFormatsText(settings: settings)
                        #if os(macOS)
                        Text("or")
                            .font(.subheadline)
                            .foregroundColor(settings.theme.secondaryTextColor)
                        #endif
                        // File browser button
                        Button("Browse Files") {
                            isImporting = true
                        }
                        .buttonStyle(.bordered)
                        .tint(settings.theme.accentColor)
                    }
                }
            }
            .padding()
        }
        .frame(height: 250)
        .onTapGesture {
            // Tap to open file browser
            isImporting = true
        }
        // ADD THIS: macOS drag and drop support
        #if os(macOS)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            return onDropFiles(providers)
        }
        #endif
    }
    
    // MARK: - Helper Methods
    
    /// Formats file size for display (KB, MB)
    private func formatFileSize(_ size: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}
