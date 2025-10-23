//
//  AddMaterialView.swift
//  QuickLit
//
//  Created by Matthew Deik on 10/17/25.
//

import SwiftUI
import UniformTypeIdentifiers
import SwiftData

// MARK: - Input Method & File Import Types

/// Defines the available methods for adding new reading material
enum InputMethod {
    case text  // Manual text input
    case file  // File import
}

/// Represents an imported file with metadata for display and processing
struct ImportedFile: Identifiable {
    let id = UUID()        // Unique identifier for SwiftUI lists
    let url: URL           // File location
    let name: String       // Display name
    let size: Int          // File size in bytes
    let `extension`: String // File extension
    let isSecurityScoped: Bool // Whether this URL needs security scoping
}

// MARK: - Add Material View

/// Main view for adding new reading materials via text input or file import
/// Supports both iOS and macOS with platform-appropriate layouts
struct AddMaterialView: View {
    // MARK: - State Bindings
    
    @Binding var showingAdder: Bool      // Controls sheet visibility
    @Binding var newContent: String      // Text content for manual input
    @Binding var newTitle: String        // Title for manual input
    @Binding var inputMethod: InputMethod // Current input mode
    @Binding var importedFiles: [ImportedFile] // Files selected for import
    @Binding var isImporting: Bool       // File picker presentation state
    @Binding var isDropTargeted: Bool    // Drag & drop highlight state
    @Binding var isUnsupportedFile: Bool // Error state for invalid files
    
    // MARK: - Dependencies
    
    @ObservedObject var settings: AppSettings  // Theme and appearance
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Callbacks
    
    let onAddNewContent: () -> Void  // Handler for text content submission
    let onImportFiles: () -> Void    // Handler for file import submission
    
    // MARK: - Computed Properties
    
    /// Array of UTTypes representing supported file formats for import
    private var allowedFileTypes: [UTType] {
        SupportedFormat.allowedUTTypes
    }
    
    var body: some View {
        // Platform-specific implementations
        #if os(macOS)
        macAddMaterialView
        #else
        iosAddMaterialView
        #endif
    }
    
    // MARK: - iOS Implementation
    
    /// iOS-optimized layout using NavigationView and compact design
    private var iosAddMaterialView: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                Text("New Reading Material")
                    .font(.headline)
                    .padding()
                    .foregroundColor(settings.theme.textColor)
                    .frame(maxWidth: .infinity)
                    .background(settings.theme.backgroundColor)
                
                // Input method picker
                Picker("Input Method", selection: $inputMethod) {
                    Text("Text").tag(InputMethod.text)
                    Text("File").tag(InputMethod.file)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(settings.theme.backgroundColor)
                
                // Dynamic content based on input method
                if inputMethod == .text {
                    textInputSection
                } else {
                    fileImportSection
                }
                
                Spacer()
                
                // Bottom action buttons
                BottomButtonArea(
                    showingAdder: $showingAdder,
                    inputMethod: $inputMethod,
                    importedFiles: $importedFiles,
                    newContent: $newContent,
                    newTitle: $newTitle,
                    isUnsupportedFile: $isUnsupportedFile,
                    settings: settings,
                    onAddNewContent: onAddNewContent,
                    onImportFiles: {
                        // Process all imported files when Add is pressed
                        processAllImportedFiles()
                        onImportFiles()
                    }
                )
            }
            .background(settings.theme.backgroundColor)
        }
        .background(settings.theme.backgroundColor)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: allowedFileTypes,
            allowsMultipleSelection: true
        ) { result in
            handleFileImportResult(result)
        }
        .presentationDetents([.medium, .large])  // iOS 16+ adaptive sheet sizing
    }
    
    // MARK: - Text Input Section
    
    /// Text input interface with title field and content editor
    private var textInputSection: some View {
        Group {
            // Title input field
            TextField("Enter title...", text: $newTitle)
                .textFieldStyle(ThemedTextFieldStyle(settings: settings))
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(settings.theme.backgroundColor)
            
            // Content text editor with placeholder
            ZStack(alignment: .topLeading) {
                TextEditor(text: $newContent)
                    .frame(height: 180)
                    .foregroundColor(settings.theme.textColor)
                    .scrollContentBackground(.hidden)  // iOS 16+ background control
                    .background(settings.theme.controlBackground)
                
                // Placeholder text when content is empty
                if newContent.isEmpty {
                    Text("Paste or type your text here...")
                        .foregroundColor(settings.theme.secondaryTextColor)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)  // Allow taps to pass through to editor
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(settings.theme.secondaryTextColor, lineWidth: 1)
            )
            .padding(.horizontal)
            .padding(.bottom)
            .background(settings.theme.backgroundColor)
        }
    }
    
    // MARK: - File Import Section
    
    /// File import interface using shared FileImportSection component
    private var fileImportSection: some View {
        FileImportSection(
            importedFiles: $importedFiles,
            isImporting: $isImporting,
            isDropTargeted: $isDropTargeted,
            isUnsupportedFile: $isUnsupportedFile,
            settings: settings,
            onRemoveFile: removeFile,
            onDropFiles: handleDroppedProviders
        )
    }
    
    // MARK: - macOS Implementation
    
    /// macOS-optimized layout with larger dimensions and desktop-appropriate styling
    private var macAddMaterialView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Reading Material")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(settings.theme.textColor)
            }
            .padding()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Input method selection
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Input Method", selection: $inputMethod) {
                            Text("Text").tag(InputMethod.text)
                            Text("File").tag(InputMethod.file)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // Dynamic content based on input method
                    if inputMethod == .text {
                        macTextInputSection
                    } else {
                        FileImportSection(
                            importedFiles: $importedFiles,
                            isImporting: $isImporting,
                            isDropTargeted: $isDropTargeted,
                            isUnsupportedFile: $isUnsupportedFile,
                            settings: settings,
                            onRemoveFile: removeFile,
                            onDropFiles: handleDroppedProviders
                        )
                    }
                }
                .padding()
            }
            
            // Bottom action buttons
            BottomButtonArea(
                showingAdder: $showingAdder,
                inputMethod: $inputMethod,
                importedFiles: $importedFiles,
                newContent: $newContent,
                newTitle: $newTitle,
                isUnsupportedFile: $isUnsupportedFile,
                settings: settings,
                onAddNewContent: onAddNewContent,
                onImportFiles: {
                    // Process all imported files when Add is pressed
                    processAllImportedFiles()
                    onImportFiles()
                }
            )
        }
        .frame(minWidth: 500, minHeight: 600)  // macOS-appropriate minimum sizes
        .background(settings.theme.backgroundColor)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: allowedFileTypes,
            allowsMultipleSelection: true
        ) { result in
            handleFileImportResult(result)
        }
    }
    
    // MARK: - macOS Text Input Section
    
    /// macOS-specific text input with enhanced styling
    private var macTextInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Title")
                .font(.headline)
                .foregroundColor(settings.theme.textColor)
            
            TextField("Enter title...", text: $newTitle)
                .textFieldStyle(ThemedTextFieldStyle(settings: settings))
            
            Text("Content")
                .font(.headline)
                .foregroundColor(settings.theme.textColor)
            
            // Content editor with placeholder
            ZStack(alignment: .topLeading) {
                TextEditor(text: $newContent)
                    .frame(height: 200)
                    .scrollContentBackground(.hidden)
                    .background(settings.theme.controlBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(settings.theme.secondaryTextColor.opacity(0.3), lineWidth: 1)
                            .padding(-5)
                    )
                
                // Placeholder text
                if newContent.isEmpty {
                    Text("Paste or type your text here...")
                        .foregroundColor(settings.theme.secondaryTextColor)
                        .allowsHitTesting(false)
                        .padding(.horizontal, 4)
                        .padding(.vertical, -2)
                }
            }
        }
        .padding()
        .background(settings.theme.controlBackground)
        .cornerRadius(8)
    }
    
    // MARK: - File Handling Methods
    
    /// Processes the result from the file importer (browse button)
    private func handleFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let files):
            // Process each selected file from file importer
            for fileURL in files {
                #if os(iOS)
                processBrowsedFileIOS(url: fileURL)
                #else
                processBrowsedFile(url: fileURL)
                #endif
            }
        case .failure(let error):
            print("Error importing files: \(error.localizedDescription)")
        }
    }
    
    /// Process files from the browse button on macOS (security-scoped URLs)
    private func processBrowsedFile(url: URL) {
        do {
            // Extract file metadata
            let resources = try url.resourceValues(forKeys: [.fileSizeKey, .nameKey])
            let fileSize = resources.fileSize ?? 0
            let fileName = resources.name ?? url.lastPathComponent
            let fileExtension = url.pathExtension
            
            // For EPUB files, try to extract chapter count for better display
            var displayName = fileName
            if fileExtension.lowercased() == "epub" {
                if let format = SupportedFormat(url: url), format == .epub {
                    do {
                        let result = try format.extractEPUBWithChapters(from: url)
                        let chapterCount = result.chapters.count
                        if chapterCount > 0 {
                            displayName = "\(fileName) (\(chapterCount) chapters)"
                        }
                    } catch {
                        print("Could not extract EPUB chapters for display: \(error)")
                        // Continue with normal file processing even if chapter extraction fails
                    }
                }
            }
            
            // Create imported file record - mark as security scoped
            let importedFile = ImportedFile(
                url: url,
                name: displayName,
                size: fileSize,
                extension: fileExtension,
                isSecurityScoped: true
            )
            
            // Add to list if not already present (avoid duplicates)
            if !importedFiles.contains(where: { $0.url == url }) {
                importedFiles.append(importedFile)
            }
            
            print("Successfully processed browsed file: \(fileName)")
            
        } catch {
            print("Error processing browsed file: \(error.localizedDescription)")
        }
    }
    
    /// Process files from the browse button on iOS (copy to app directory)
    private func processBrowsedFileIOS(url: URL) {
        do {
            // On iOS, we need to copy the file to our app's documents directory
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access security scoped resource on iOS")
                return
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            // Copy file to app's documents directory
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationURL = documentsURL.appendingPathComponent(url.lastPathComponent)
            
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            try FileManager.default.copyItem(at: url, to: destinationURL)
            
            // Extract file metadata from the copied file
            let resources = try destinationURL.resourceValues(forKeys: [.fileSizeKey, .nameKey])
            let fileSize = resources.fileSize ?? 0
            let fileName = resources.name ?? url.lastPathComponent
            let fileExtension = url.pathExtension
            
            // For EPUB files, try to extract chapter count for better display
            var displayName = fileName
            if fileExtension.lowercased() == "epub" {
                if let format = SupportedFormat(url: destinationURL), format == .epub {
                    do {
                        let result = try format.extractEPUBWithChapters(from: destinationURL)
                        let chapterCount = result.chapters.count
                        if chapterCount > 0 {
                            displayName = "\(fileName) (\(chapterCount) chapters)"
                        }
                    } catch {
                        print("Could not extract EPUB chapters for display: \(error)")
                        // Continue with normal file processing even if chapter extraction fails
                    }
                }
            }
            
            // Create imported file record - mark as NOT security scoped since it's in our app directory
            let importedFile = ImportedFile(
                url: destinationURL,
                name: displayName,
                size: fileSize,
                extension: fileExtension,
                isSecurityScoped: false
            )
            
            // Add to list if not already present (avoid duplicates)
            if !importedFiles.contains(where: { $0.url == destinationURL }) {
                importedFiles.append(importedFile)
            }
            
            print("Successfully processed browsed file on iOS: \(fileName)")
            
        } catch {
            print("Error processing browsed file on iOS: \(error.localizedDescription)")
        }
    }
    
    /// Process all imported files when Add button is pressed
    private func processAllImportedFiles() {
        for importedFile in importedFiles {
            importFile(from: importedFile)
        }
        
        // Clear imported files after processing
        importedFiles.removeAll()
    }
    
    /// Removes a file from the imported files list
    private func removeFile(_ file: ImportedFile) {
        importedFiles.removeAll { $0.id == file.id }
        
        // On iOS, also remove the copied file from documents directory
        #if os(iOS)
        if !file.isSecurityScoped {
            try? FileManager.default.removeItem(at: file.url)
        }
        #endif
    }
    
    /// Formats file size for human-readable display
    private func formatFileSize(_ size: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
    
    // MARK: - Drag & Drop Support
    
    /// Handles files dropped via drag & drop
    func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        var hasValidFiles = false
        
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                if let error = error {
                    print("Error loading item: \(error.localizedDescription)")
                    return
                }
                
                // Handle different data types that can represent URLs
                if let data = item as? Data,
                   let path = String(data: data, encoding: .utf8),
                   let url = URL(string: path) {
                    DispatchQueue.main.async {
                        self.handleDroppedFile(url: url)
                    }
                } else if let url = item as? URL {
                    DispatchQueue.main.async {
                        self.handleDroppedFile(url: url)
                    }
                }
            }
            hasValidFiles = true
        }
        return hasValidFiles
    }
    
    /// Validates and processes a dropped file
    func handleDroppedFile(url: URL) {
        let fileExtension = url.pathExtension.lowercased()
        
        // Check if file format is supported
        guard SupportedFormat.supportedExtensions.contains(fileExtension) else {
            print("Unsupported file type: \(fileExtension)")
            isUnsupportedFile = true
            // Auto-dismiss error after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    self.isUnsupportedFile = false
                }
            }
            return
        }
        
        isUnsupportedFile = false
        
        // Process the dropped file directly
        #if os(iOS)
        processDroppedFileIOS(url: url)
        #else
        processDroppedFile(url: url)
        #endif
    }
    
    /// Processes a dropped file directly without security scoping issues (macOS)
    func processDroppedFile(url: URL) {
        do {
            // Extract file metadata
            let resources = try url.resourceValues(forKeys: [.fileSizeKey, .nameKey])
            let fileSize = resources.fileSize ?? 0
            let fileName = resources.name ?? url.lastPathComponent
            let fileExtension = url.pathExtension
            
            // For EPUB files, try to extract chapter count for better display
            var displayName = fileName
            if fileExtension.lowercased() == "epub" {
                if let format = SupportedFormat(url: url), format == .epub {
                    do {
                        let result = try format.extractEPUBWithChapters(from: url)
                        let chapterCount = result.chapters.count
                        if chapterCount > 0 {
                            displayName = "\(fileName) (\(chapterCount) chapters)"
                        }
                    } catch {
                        print("Could not extract EPUB chapters for display: \(error)")
                        // Continue with normal file processing even if chapter extraction fails
                    }
                }
            }
            
            // Create imported file record - mark as NOT security scoped
            let importedFile = ImportedFile(
                url: url,
                name: displayName,
                size: fileSize,
                extension: fileExtension,
                isSecurityScoped: false
            )
            
            // Add to list if not already present (avoid duplicates)
            if !importedFiles.contains(where: { $0.url == url }) {
                importedFiles.append(importedFile)
            }
            
            print("Successfully processed dropped file: \(fileName)")
            
        } catch {
            print("Error processing dropped file: \(error.localizedDescription)")
        }
    }
    
    /// Processes a dropped file on iOS (copy to app directory)
    func processDroppedFileIOS(url: URL) {
        do {
            // On iOS, copy dropped files to app's documents directory for consistent access
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationURL = documentsURL.appendingPathComponent(url.lastPathComponent)
            
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            try FileManager.default.copyItem(at: url, to: destinationURL)
            
            // Extract file metadata from the copied file
            let resources = try destinationURL.resourceValues(forKeys: [.fileSizeKey, .nameKey])
            let fileSize = resources.fileSize ?? 0
            let fileName = resources.name ?? url.lastPathComponent
            let fileExtension = url.pathExtension
            
            // For EPUB files, try to extract chapter count for better display
            var displayName = fileName
            if fileExtension.lowercased() == "epub" {
                if let format = SupportedFormat(url: destinationURL), format == .epub {
                    do {
                        let result = try format.extractEPUBWithChapters(from: destinationURL)
                        let chapterCount = result.chapters.count
                        if chapterCount > 0 {
                            displayName = "\(fileName) (\(chapterCount) chapters)"
                        }
                    } catch {
                        print("Could not extract EPUB chapters for display: \(error)")
                        // Continue with normal file processing even if chapter extraction fails
                    }
                }
            }
            
            // Create imported file record - mark as NOT security scoped since it's in our app directory
            let importedFile = ImportedFile(
                url: destinationURL,
                name: displayName,
                size: fileSize,
                extension: fileExtension,
                isSecurityScoped: false
            )
            
            // Add to list if not already present (avoid duplicates)
            if !importedFiles.contains(where: { $0.url == destinationURL }) {
                importedFiles.append(importedFile)
            }
            
            print("Successfully processed dropped file on iOS: \(fileName)")
            
        } catch {
            print("Error processing dropped file on iOS: \(error.localizedDescription)")
        }
    }
    
    /// Import file with proper handling for both dropped and browsed files
    private func importFile(from importedFile: ImportedFile) {
        do {
            let url = importedFile.url
            
            // For security-scoped files (from browse button on macOS), we need to access the resource
            if importedFile.isSecurityScoped {
                guard url.startAccessingSecurityScopedResource() else {
                    print("Failed to access security scoped resource for import")
                    return
                }
            }
            
            defer {
                if importedFile.isSecurityScoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            // Read file content
            guard let format = SupportedFormat(url: url) else {
                print("Unsupported format")
                return
            }
            
            // For EPUB files, extract both text and chapter information
            if case .epub = format {
                let result = try format.extractEPUBWithChapters(from: url)
                
                // Use filename as title (remove extension)
                let title = newTitle.isEmpty ? url.deletingPathExtension().lastPathComponent : newTitle
                
                // Create new reading material with chapter information
                let material = ReadingMaterial(title: title, content: result.fullText, chapters: result.chapters)
                modelContext.insert(material)
                
                print("Successfully imported EPUB with \(result.chapters.count) chapters as: \(title)")
            } else {
                // For other formats, use plain text extraction
                let content = try format.plainText(from: url)
                
                // Use filename as title (remove extension)
                let title = newTitle.isEmpty ? url.deletingPathExtension().lastPathComponent : newTitle
                
                // Create new reading material
                let material = ReadingMaterial(title: title, content: content)
                modelContext.insert(material)
                
                print("Successfully imported file as: \(title)")
            }
            
            // Clean up copied files on iOS
            #if os(iOS)
            if !importedFile.isSecurityScoped {
                try? FileManager.default.removeItem(at: url)
            }
            #endif
            
        } catch {
            print("Error reading file: \(error.localizedDescription)")
            
            // Clean up copied files on iOS even if there's an error
            #if os(iOS)
            if !importedFile.isSecurityScoped {
                try? FileManager.default.removeItem(at: importedFile.url)
            }
            #endif
        }
    }
}
