//
//  ContentView.swift
//  QuickLit
//
//  Created by Matthew Deik on 8/19/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Main application view that displays the library of reading materials
/// Handles navigation, material management, and user interactions
struct ContentView: View {
    // MARK: - Data & Environment
    
    @Environment(\.modelContext) private var modelContext  // SwiftData context for persistence
    @Query(sort: \ReadingMaterial.lastReadDate, order: .reverse) private var materials: [ReadingMaterial]  // Sorted by most recently read
    @StateObject private var settings = AppSettings()  // App-wide settings and theme management
    
    // MARK: - Add Material State
    
    @State private var showingAdder = false      // Controls Add Material sheet presentation
    @State private var newContent = ""           // Text content for new material
    @State private var newTitle = ""             // Title for new material
    @State private var inputMethod: InputMethod = .text  // Text vs File input mode
    @State private var importedFiles: [ImportedFile] = []  // Files selected for import
    @State private var isImporting = false       // File picker presentation state
    @State private var isDropTargeted = false    // Drag & drop visual feedback
    @State private var isUnsupportedFile = false // Error state for invalid files
    
    // MARK: - App State & Preferences
    
    /// Tracks whether sample content has been automatically added (first launch experience)
    @AppStorage("hasAddedSampleAutomatically") private var hasAddedSampleAutomatically = false
    
    // MARK: - Selection Mode State
    
    @State private var selectMode: Bool = false  // Whether multi-select mode is active
    @State private var selectedMaterials: Set<ReadingMaterial> = []  // Currently selected materials
    
    // MARK: - iOS-Only Sharing State
    
    #if os(iOS)
    @State private var isSharing = false  // Share sheet presentation state
    @State private var shareItems: [URL] = []  // Temporary files for sharing
    #endif
    
    // MARK: - Computed Properties
    
    /// Platform detection for conditional compilation
    private var isIOS: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }
    
    /// Whether any materials are currently selected
    private var hasSelectedItems: Bool {
        !selectedMaterials.isEmpty
    }
    
    var body: some View {
        // Main navigation structure with sidebar and detail view
        NavigationSplitView {
            ZStack(alignment: .bottom) {
                // List of reading materials
                List {
                    ForEach(materials) { material in
                        HStack {
                            // Selection checkbox (only visible in select mode)
                            if selectMode {
                                Button(action: {
                                    toggleSelection(for: material)
                                }) {
                                    Image(systemName: selectedMaterials.contains(material) ?
                                          "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedMaterials.contains(material) ?
                                                       settings.theme.accentColor : settings.theme.secondaryTextColor)
                                }
                                .accessibilityLabel(selectedMaterials.contains(material) ?
                                                  "Deselect \(material.title)" : "Select \(material.title)")
                                .accessibilityHint("Double tap to toggle selection")
                            }
                            
                            // Navigation link to reader view
                            NavigationLink {
                                ReaderView(material: material)
                            } label: {
                                ReadingMaterialRow(material: material, settings: settings)
                            }
                            .disabled(selectMode)  // Disable navigation during selection
                            .accessibilityElement(children: .combine)
                            .accessibilityHint("Double tap to open reading view")
                        }
                        // Swipe actions for quick operations
                        .swipeActions(edge: .trailing) {
                            if !selectMode {
                                Button(role: .destructive) {
                                    deleteMaterial(material)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .accessibilityLabel("Delete \(material.title)")

                                Button {
                                    renameMaterial(material)
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(settings.theme.accentColor)
                                .accessibilityLabel("Rename \(material.title)")
                            }
                        }
                        // Context menu for additional options
                        .contextMenu {
                            if !selectMode {
                                Button {
                                    renameMaterial(material)
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .accessibilityLabel("Rename \(material.title)")

                                Button(role: .destructive) {
                                    deleteMaterial(material)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .accessibilityLabel("Delete \(material.title)")
                            }
                        }
                        #if os(iOS)
                        .listRowBackground(settings.theme.controlBackground)  // Theme-appropriate row background
                        #endif
                    }
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)  // Use custom background
                .background(settings.theme.backgroundColor)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Reading materials list")
                .accessibilityHint("Swipe left on any item for more options")
                
                // Selection toolbar (shown when in select mode)
                if selectMode {
                    selectionToolbar
                }
            }
            .navigationTitle("Reading Materials")
            .foregroundColor(settings.theme.textColor)
            .toolbar {
                if !selectMode {
                    // Normal mode toolbar items
                    ToolbarItem(placement: .primaryAction) {
                        #if os(iOS)
                        // iOS: Context menu for add button with multiple options
                        Menu {
                            Button {
                                showingAdder = true
                            } label: {
                                Label("Add New Material", systemImage: "plus")
                            }
                            .accessibilityLabel("Add new reading material")
                            
                            Button {
                                addSampleContent()
                            } label: {
                                Label("Add Sample Reading", systemImage: "text.book.closed")
                            }
                            .accessibilityLabel("Add sample reading material")
                        } label: {
                            Label("Add", systemImage: "plus")
                        }
                        .foregroundColor(settings.theme.accentColor)
                        .accessibilityLabel("Add menu")
                        .accessibilityHint("Double tap to show options for adding new content")
                        #else
                        // macOS: Simple add button
                        Button(action: { showingAdder = true }) {
                            Label("Add New", systemImage: "plus")
                        }
                        .foregroundColor(settings.theme.accentColor)
                        .accessibilityLabel("Add new reading material")
                        #endif
                    }
                    
                    // Selection mode toggle button
                    ToolbarItem(placement: .automatic) {
                        Button(action: {
                            selectMode = true
                        }) {
                            Label("Select", systemImage: "checkmark.circle")
                        }
                        .foregroundColor(settings.theme.accentColor)
                        .disabled(materials.isEmpty)  // Disable if no materials available
                        .accessibilityLabel("Enter selection mode")
                        .accessibilityHint(materials.isEmpty ?
                                         "No materials available to select" :
                                         "Double tap to select multiple materials")
                    }
                }
            }
            #if os(macOS)
            // macOS: Context menu for empty list area
            .contextMenu {
                if !selectMode {
                    Button {
                        addSampleContent()
                    } label: {
                        Label("Add Sample Reading", systemImage: "text.book.closed")
                    }
                    .accessibilityLabel("Add sample reading material")
                }
            }
            #endif
        } detail: {
            // Empty state for detail view
            Text("Select a reading material or create a new one")
                .foregroundColor(settings.theme.secondaryTextColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(settings.theme.backgroundColor)
                .accessibilityLabel("Content area")
                .accessibilityHint("Select an item from the sidebar or create a new reading material")
        }
        .onAppear {
            
            // First launch experience: add sample content if no materials exist
            if materials.isEmpty && !hasAddedSampleAutomatically {
                addSampleContent()
                hasAddedSampleAutomatically = true
            }
        }
        // Add Material sheet
        .sheet(isPresented: $showingAdder) {
            AddMaterialView(
                showingAdder: $showingAdder,
                newContent: $newContent,
                newTitle: $newTitle,
                inputMethod: $inputMethod,
                importedFiles: $importedFiles,
                isImporting: $isImporting,
                isDropTargeted: $isDropTargeted,
                isUnsupportedFile: $isUnsupportedFile,
                settings: settings,
                onAddNewContent: addNewContent,
                onImportFiles: importFiles
            )
        }
        // iOS Share sheet
        #if os(iOS)
        .sheet(isPresented: $isSharing) {
            if shareItems.first != nil {
                ActivityViewController(activityItems: shareItems, applicationActivities: nil)
                    .onDisappear {
                        // Clean up temporary files after sharing
                        for fileURL in shareItems {
                            try? FileManager.default.removeItem(at: fileURL)
                        }
                        shareItems.removeAll()
                        selectedMaterials.removeAll()
                        selectMode = false
                    }
            }
        }
        #endif
    }
    
    // MARK: - Selection Toolbar
    
    /// Bottom toolbar shown during multi-select mode with action buttons
    private var selectionToolbar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(settings.theme.secondaryTextColor.opacity(0.3))
            
            HStack {
                // Cancel selection button
                Button("Cancel") {
                    selectMode = false
                    selectedMaterials.removeAll()
                }
                .foregroundColor(settings.theme.secondaryTextColor)
                .accessibilityLabel("Cancel selection")
                
                Spacer()
                
                // Selection count display
                Text("\(selectedMaterials.count) Selected")
                    .foregroundColor(settings.theme.textColor)
                    .font(.headline)
                    .accessibilityLabel("\(selectedMaterials.count) items selected")
                
                Spacer()
                
                // iOS Share Button
                #if os(iOS)
                Button(action: shareSelectedMaterials) {
                    Label("", systemImage: "square.and.arrow.up")
                        .foregroundColor(hasSelectedItems ? settings.theme.accentColor : .gray)
                }
                .disabled(!hasSelectedItems)
                .accessibilityLabel("Share selected items")
                .accessibilityHint(hasSelectedItems ?
                                 "Double tap to share selected materials" :
                                 "No items selected to share")
                #endif
                
                // Delete selected materials button
                Button(action: {
                    #if os(iOS)
                    showDeleteConfirmation()
                    #else
                    deleteSelectedMaterials()
                    #endif
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(hasSelectedItems ? .red : .gray)
                }
                .disabled(!hasSelectedItems)
                .accessibilityLabel("Delete selected items")
                .accessibilityHint(hasSelectedItems ?
                                 "Double tap to delete selected materials" :
                                 "No items selected to delete")
            }
            .padding()
            .background(settings.theme.backgroundColor)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Selection toolbar")
        }
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - Selection Management
    
    /// Toggles selection state for a specific material
    private func toggleSelection(for material: ReadingMaterial) {
        if selectedMaterials.contains(material) {
            selectedMaterials.remove(material)
        } else {
            selectedMaterials.insert(material)
        }
    }
    
    // MARK: - Sharing Methods (iOS only)
    
    #if os(iOS)
    /// Creates temporary files and presents share sheet for selected materials
    private func shareSelectedMaterials() {
        let tempDirectory = FileManager.default.temporaryDirectory
        var shareURLs: [URL] = []
        
        // Create text files for each selected material
        for material in selectedMaterials {
            let fileName = "\(material.title).txt".sanitizedFileName
            let fileURL = tempDirectory.appendingPathComponent(fileName)
            
            do {
                try material.content.write(to: fileURL, atomically: true, encoding: .utf8)
                shareURLs.append(fileURL)
            } catch {
                print("Failed to create share file for \(material.title): \(error)")
            }
        }
        
        shareItems = shareURLs
        isSharing = true
    }
    
    /// Shows confirmation alert before deleting selected materials
    private func showDeleteConfirmation() {
        let alert = UIAlertController(
            title: "Delete Materials",
            message: "Are you sure you want to delete \(selectedMaterials.count) material(s)?",
            preferredStyle: .alert
        )

        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { _ in
            deleteSelectedMaterials()
        }
        deleteAction.accessibilityLabel = "Confirm delete"

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        cancelAction.accessibilityLabel = "Cancel delete"

        alert.addAction(deleteAction)
        alert.addAction(cancelAction)

        // Present alert on the root view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
    #endif
    
    /// Deletes all currently selected materials
    private func deleteSelectedMaterials() {
        for material in selectedMaterials {
            deleteMaterial(material)
        }
        selectedMaterials.removeAll()
        selectMode = false
    }
    
    // MARK: - Material Management
    
    /// Creates and saves a new reading material from text input
    private func addNewContent() {
        guard !newContent.isEmpty else { return }
        let material = ReadingMaterial(
            title: newTitle.isEmpty ? "Untitled" : newTitle,
            content: newContent
        )
        modelContext.insert(material)
        
        do {
            try modelContext.save()
            print("Successfully saved new material: \(material.title)")
        } catch {
            print("Failed to save new material: \(error)")
        }
        
        // Reset form fields
        newContent = ""
        newTitle = ""
    }
    
    /// Processes all imported files and creates reading materials from them
    private func importFiles() {
        for importedFile in importedFiles {
            importFile(from: importedFile.url)
        }
        importedFiles.removeAll()
        newTitle = ""
    }
    
    /// Imports a single file and creates a reading material from it
    private func importFile(from url: URL) {
        do {
            // Access security-scoped resource for file access
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access security scoped resource for import")
                return
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            // Detect format and extract text content
            guard let format = SupportedFormat(url: url) else {
                print("Unsupported format")
                return
            }
            
            let title = url.deletingPathExtension().lastPathComponent
            
            // Use enhanced EPUB extraction for chapters, standard extraction for other formats
            if format == .epub {
                let result = try format.extractEPUBWithChapters(from: url)
                let material = ReadingMaterial(
                    title: title,
                    content: result.fullText,
                    chapters: result.chapters
                )
                modelContext.insert(material)
            } else {
                let content = try format.plainText(from: url)
                let material = ReadingMaterial(title: title, content: content)
                modelContext.insert(material)
            }
            
            do {
                try modelContext.save()
                print("Successfully imported and saved: \(title)")
            } catch {
                print("Failed to save imported material: \(error)")
            }
            
        } catch {
            print("Error reading file: \(error.localizedDescription)")
        }
    }
    
    /// Adds sample content for first-time users
    private func addSampleContent() {
        let sample = ReadingMaterial(
            title: "Sample Text",
            content: "Unlock a faster, more efficient way to read. Rapid Serial Visual Presentation (RSVP) displays each word in a single, focused point, training your brain to process information without the inefficiency of your eyes scanning back and forth. By finding your perfect speed, you can minimize distractions and subvocalization, allowing you to concentrate deeply on the text. This focused practice doesn't just increase your words-per-minute; it actively trains your brain for better comprehension and retention, helping you absorb more information in less time."
        )
        modelContext.insert(sample)
        
        do {
            try modelContext.save()
            print("Sample content added and saved")
        } catch {
            print("Failed to save sample content: \(error)")
        }
    }
    
    /// Deletes a specific reading material
    private func deleteMaterial(_ material: ReadingMaterial) {
        modelContext.delete(material)
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete material: \(error)")
        }
    }

    /// Renames a reading material with platform-appropriate UI
    private func renameMaterial(_ material: ReadingMaterial) {
        #if os(iOS)
        // iOS: Show alert with text field
        let alert = UIAlertController(
            title: "Rename Material",
            message: "Enter a new title",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.text = material.title
            textField.accessibilityLabel = "New title"
        }

        let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
            if let newTitle = alert.textFields?.first?.text, !newTitle.isEmpty {
                material.title = newTitle
                do {
                    try modelContext.save()
                } catch {
                    print("Failed to rename material: \(error)")
                }
            }
        }
        saveAction.accessibilityLabel = "Save new title"

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        cancelAction.accessibilityLabel = "Cancel rename"

        alert.addAction(saveAction)
        alert.addAction(cancelAction)

        // Present alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true)
        }
        #else
        // macOS: Simple rename (could be enhanced with proper dialog)
        material.title = "Renamed Material"
        do {
            try modelContext.save()
        } catch {
            print("Failed to rename material: \(error)")
        }
        #endif
    }
    
    // MARK: - iOS Navigation Bar Appearance
    
    #if os(iOS)
    /// Configures global navigation bar appearance
    func setupGlobalNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(settings.theme.backgroundColor)
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(settings.theme.textColor),
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(settings.theme.textColor),
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        
        // Apply to all navigation bar styles
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(settings.theme.accentColor)
        
        // Improve accessibility
        UINavigationBar.appearance().isAccessibilityElement = true
    }

    /// Updates navigation bar title color dynamically
    func updateNavigationBarTitleColor() {
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                for window in windowScene.windows {
                    if let navigationController = findNavigationController(in: window) {
                        let appearance = UINavigationBarAppearance()
                        appearance.configureWithOpaqueBackground()
                        appearance.titleTextAttributes = [.foregroundColor: UIColor(settings.theme.textColor)]
                        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(settings.theme.textColor)]
                        
                        navigationController.navigationBar.standardAppearance = appearance
                        navigationController.navigationBar.scrollEdgeAppearance = appearance
                        navigationController.navigationBar.compactAppearance = appearance
                        navigationController.navigationBar.tintColor = UIColor(settings.theme.accentColor)
                    }
                }
            }
        }
    }

    /// Recursively finds navigation controller in view hierarchy
    func findNavigationController(in window: UIWindow) -> UINavigationController? {
        if let navigationController = window.rootViewController as? UINavigationController {
            return navigationController
        }
        
        func findNavController(in viewController: UIViewController?) -> UINavigationController? {
            guard let viewController = viewController else { return nil }
            
            if let navigationController = viewController as? UINavigationController {
                return navigationController
            }
            
            // Search child view controllers
            for child in viewController.children {
                if let found = findNavController(in: child) {
                    return found
                }
            }
            
            // Search presented view controllers
            if let presented = viewController.presentedViewController {
                return findNavController(in: presented)
            }
            
            return nil
        }
        
        return findNavController(in: window.rootViewController)
    }
    #endif
}

// MARK: - Supporting Types and Extensions (iOS only)

#if os(iOS)
/// Wrapper for UIActivityViewController to use in SwiftUI
struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {
        // No updates needed
    }
}
#endif

// MARK: - String Extension

extension String {
    /// Sanitizes string for use as a filename by removing invalid characters
    var sanitizedFileName: String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>")
        return self.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
}

// MARK: - Preview

#Preview {
    ContentView().modelContainer(for: ReadingMaterial.self, inMemory: true)
}
