//
//  ReaderView.swift
//  QuickLit
//
//  Created by Matthew Deik on 8/21/25.
//

import SwiftUI
import SwiftData

// MARK: - Reader View

/// Main reading interface implementing Rapid Serial Visual Presentation (RSVP)
/// Displays words in sequence with center focus and peripheral context words
struct ReaderView: View {
    // MARK: - Data Dependencies
    let material: ReadingMaterial
    @StateObject private var viewModel: ReadingViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Presentation State
    @State private var showingStats = false
    @State private var showingConfig = false
    @State private var showingAltReader = false

    // MARK: - Chapter Management
    @State private var chapters: [EPUBChapter] = []
    @State private var currentChapterIndex: Int = 0

    // MARK: - UI Interaction State
    @State private var isSliderDragging = false
    @State private var isDragging = false
    @State private var isUIVisible = true
    
    // MARK: - Drag Gesture State
    @State private var lastDragTime = Date()
    @State private var lastDragValue: CGFloat = 0
    @State private var visualDragOffset: CGFloat = 0
    @State private var actualDragOffset: CGFloat = 0
    @State private var dragVelocity: CGFloat = 0

    // MARK: - State Preservation
    @State private var wasPlayingBeforeConfig = false
    @State private var wasPlayingBeforeDrag = false
    @State private var hideUITimer: Timer?

    // MARK: - Performance Optimizations
    // Cached values to avoid reading ObservableObject inside computed properties
    @State private var currentProgress: CGFloat = 0
    @State private var isVertical: Bool = false

    init(material: ReadingMaterial) {
        self.material = material
        _viewModel = StateObject(wrappedValue: ReadingViewModel())
    }

    var body: some View {
        ZStack {
            // Background uses theme color
            settings.theme.backgroundColor
                .ignoresSafeArea()
                .contentShape(Rectangle())
            
            VStack(spacing: 0) {
                if isUIVisible { progressSection }
                readingDisplaySection
                if isUIVisible { controlsSection }
            }
        }
        // MARK: - iOS Specific Navigation Bar Configuration
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(settings.autoHideUI ? (isUIVisible ? .visible : .hidden) : .visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(material.title)
                    .font(.headline)
                    .foregroundColor(viewModel.settings.theme.textColor)
            }
        }
        .toolbarBackground(viewModel.settings.theme.backgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
        // MARK: - View Lifecycle
        .onAppear {
            viewModel.loadMaterial(material, modelContext: modelContext)
            loadChapters()
            ensureUIVisibilityForCurrentSettings()
            resetHideUITimer()
            // Initialize cached values for performance
            currentProgress = CGFloat(viewModel.currentPosition) / CGFloat(max(1, viewModel.totalWords))
            isVertical = viewModel.settings.verticalReading
        }
        .onDisappear {
            viewModel.pauseReading()
            hideUITimer?.invalidate()
            try? modelContext.save() // Persist reading progress
        }
        .onChange(of: viewModel.currentPosition) { _, newPosition in
            updateCurrentChapter(for: newPosition)
            currentProgress = CGFloat(newPosition) / CGFloat(max(1, viewModel.totalWords))
        }
        .onChange(of: viewModel.settings.verticalReading) { _, new in
            isVertical = new // Update cached value when setting changes
        }
        // MARK: - Sheet Presentations
        .sheet(isPresented: $showingStats) {
            StatsView(material: material, viewModel: viewModel)
        }
        .sheet(isPresented: $showingConfig, onDismiss: {
            // Resume reading if it was playing before config opened
            if wasPlayingBeforeConfig {
                viewModel.startReading()
                wasPlayingBeforeConfig = false
            }
            ensureUIVisibilityForCurrentSettings()
            resetHideUITimer()
        }) {
            ConfigurationView(settings: viewModel.settings)
        }
        .onChange(of: material.id) { _, _ in
            // Reload when material changes
            viewModel.loadMaterial(material, modelContext: modelContext)
            loadChapters()
        }
        .onChange(of: viewModel.isPlaying) { _, isPlaying in
            if isPlaying { resetHideUITimer() } // Keep UI visible during reading
        }
        #if os(iOS)
        .onChange(of: settings.autoHideUI) { _, _ in
            ensureUIVisibilityForCurrentSettings()
        }
        #endif
    }

    // MARK: - Progress Section
    private var progressSection: some View {
        Group {
            VStack(spacing: 8) {
                // Chapter title
                if !chapters.isEmpty && currentChapterIndex < chapters.count {
                    HStack {
                        Text(chapters[currentChapterIndex].title)
                            .font(.caption)
                            .foregroundColor(viewModel.settings.theme.secondaryTextColor)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                // ---  slider + live chapter notches  ------------------------------
                GeometryReader { geo in
                    let w = geo.size.width          // real width at layout time
                    ZStack(alignment: .leading) {

                        // invisible slider that the user drags
                        Slider(
                            value: .init(
                                get: { Double(viewModel.currentPosition) },
                                set: { viewModel.seek(to: Int($0)) }
                            ),
                            in: 0...Double(max(0, viewModel.totalWords - 1))
                        ) { editing in
                            isSliderDragging = editing
                            if editing {
                                wasPlayingBeforeDrag = viewModel.isPlaying
                                viewModel.pauseReading()
                                resetHideUITimer()
                            } else {
                                if wasPlayingBeforeDrag {
                                    viewModel.startReading()
                                    wasPlayingBeforeDrag = false
                                }
                            }
                        }
                        .accentColor(viewModel.settings.highlightColor)

                        // chapter notches – positions recalculated on every layout
                        if !chapters.isEmpty {
                            ForEach(chapters) { ch in
                                if ch.startPosition > 0 && ch.startPosition < viewModel.totalWords {
                                    let notchX = CGFloat(ch.startPosition)
                                        / CGFloat(max(1, viewModel.totalWords)) * w
                                    Rectangle()
                                        .fill(viewModel.settings.theme.textColor.opacity(0.6))
                                        .frame(width: 2, height: 12)
                                        .position(x: notchX, y: geo.frame(in: .local).midY)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                    }
                }
                .frame(height: 44)
                .padding(.horizontal)

                // progress text
                HStack {
                    if !chapters.isEmpty {
                        Text("Chapter \(currentChapterIndex + 1) of \(chapters.count)")
                            .font(.caption)
                            .foregroundColor(viewModel.settings.theme.secondaryTextColor)
                    }
                    Spacer()
                    Text("\(viewModel.currentPosition + 1)/\(viewModel.totalWords)")
                        .font(.caption)
                        .foregroundColor(viewModel.settings.theme.secondaryTextColor)
                }
                .padding(.horizontal)
            }
            .padding(.top, 12)
        }
    }

    // MARK: - Slider Helpers
   
    /// Applies magnetic snap to nearest chapter boundary when slider is released
    private func applyMagneticSnap(to position: Int) {
        guard !chapters.isEmpty else { return }
        if let nearest = findNearestChapter(to: position),
           abs(nearest.startPosition - position) < viewModel.totalWords / 50 { // 2% threshold
            viewModel.seek(to: nearest.startPosition)
        }
    }
    
    private func findNearestChapter(to position: Int) -> EPUBChapter? {
        chapters.min { abs($0.startPosition - position) < abs($1.startPosition - position) }
    }

    // MARK: - Reading Display Section
    private var readingDisplaySection: some View {
        Text(attributedContent)
            .multilineTextAlignment(.center)
            .lineSpacing(isVertical ? 8 : 0)
            .lineLimit(isVertical ? nil : 1) // Single line for horizontal, multi-line for vertical
            .minimumScaleFactor(0.5)
            .offset(
                x: isVertical ? 0 : visualDragOffset,
                y: isVertical ? visualDragOffset : 0
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .textSelection(.enabled)
            .allowsHitTesting(!isDragging) // Disable text selection during drag
            .overlay(
                Group {
                    if isDragging {
                        // Visual feedback during drag gesture
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(viewModel.settings.highlightColor.opacity(0.5), lineWidth: 2)
                            .padding(4)
                    }
                }
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        handleDragChange(value)
                    }
                    .onEnded { value in
                        handleDragEnd(value)
                    }
            )
            .onTapGesture {
                #if os(iOS)
                toggleUIVisibility()
                #endif
            }
    }

    // MARK: - Controls Section
    private var controlsSection: some View {
        VStack {
            HStack {
                // Navigation controls
                Button(action: {
                    resetHideUITimer(); viewModel.moveBackward()
                }) {
                    Image(systemName: "arrow.left")
                }
                .foregroundColor(viewModel.settings.theme.accentColor)
                
                Button(action: {
                    resetHideUITimer(); viewModel.moveForward()
                }) {
                    Image(systemName: "arrow.right")
                }
                .foregroundColor(viewModel.settings.theme.accentColor)
                
                Spacer()
                
                // Configuration and playback controls
                Button(action: {
                    resetHideUITimer()
                    wasPlayingBeforeConfig = viewModel.isPlaying
                    viewModel.pauseReading()
                    showingConfig = true
                }) {
                    Image(systemName: "gear")
                }
                .foregroundColor(viewModel.settings.theme.accentColor)
                
                Button(action: {
                    resetHideUITimer()
                    viewModel.isPlaying ? viewModel.pauseReading() : viewModel.startReading()
                }) {
                    Text(viewModel.isPlaying ? "Pause" : "Play")
                        .frame(width: 60, alignment: .center)
                }
                .foregroundColor(viewModel.settings.theme.accentColor)
            }
        }
        .padding()
        .background(viewModel.settings.theme.controlBackground)
    }

    // MARK: - Chapter Management
    private func loadChapters() {
        // Reset chapters state first
        chapters = []
        currentChapterIndex = 0
        
        // Only load chapters if the material has them
        if let materialChapters = material.chapters {
            chapters = materialChapters.sorted { $0.startPosition < $1.startPosition }
            updateCurrentChapter(for: viewModel.currentPosition)
        }
    }
    
    private func updateCurrentChapter(for position: Int) {
        guard !chapters.isEmpty else { return }
        var newIndex = 0
        // Find the current chapter based on position
        for (index, chapter) in chapters.enumerated() {
            if chapter.startPosition <= position {
                newIndex = index
            } else {
                break
            }
        }
        if newIndex != currentChapterIndex {
            currentChapterIndex = newIndex
        }
    }

    // MARK: - Auto Hide UI Management
    private func ensureUIVisibilityForCurrentSettings() {
        #if os(iOS)
        if !settings.autoHideUI && !isUIVisible {
            withAnimation(.easeInOut(duration: 0.2)) {
                isUIVisible = true
            }
            hideUITimer?.invalidate()
            hideUITimer = nil
        }
        #endif
    }
    
    private func toggleUIVisibility() {
        #if os(iOS)
        guard settings.autoHideUI else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            isUIVisible.toggle()
        }
        isUIVisible ? resetHideUITimer() : hideUITimer?.invalidate()
        #endif
    }
    
    private func resetHideUITimer() {
        hideUITimer?.invalidate()
        #if os(iOS)
        let shouldSet = isUIVisible && settings.autoHideUI
        if shouldSet {
            hideUITimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isUIVisible = false
                }
            }
        }
        #endif
    }

    // MARK: - Drag Gesture Handling
    private func handleDragChange(_ value: DragGesture.Value) {
        isDragging = true
        
        // Show UI during drag if auto-hide is enabled
        #if os(iOS)
        if !isUIVisible && settings.autoHideUI {
            withAnimation(.easeInOut(duration: 0.2)) {
                isUIVisible = true
            }
        }
        #else
        if !isUIVisible {
            withAnimation(.easeInOut(duration: 0.2)) {
                isUIVisible = true
            }
        }
        #endif
        
        resetHideUITimer()
        
        // Calculate drag velocity and delta
        let now = Date()
        let timeDelta = now.timeIntervalSince(lastDragTime)
        lastDragTime = now
        
        let primaryTranslation = isVertical ? value.translation.height : value.translation.width
        let dragDelta = primaryTranslation - lastDragValue
        lastDragValue = primaryTranslation
        
        dragVelocity = timeDelta > 0 ? dragDelta / CGFloat(timeDelta) / 2 : 0
        visualDragOffset = primaryTranslation
        actualDragOffset = primaryTranslation
        
        // Handle edge cases (start/end of content)
        let isAtStart = viewModel.currentPosition == 0
        let isAtEnd = viewModel.currentPosition == viewModel.totalWords - 1
        if (isAtStart && dragDelta > 0) || (isAtEnd && dragDelta < 0) {
            visualDragOffset *= 0.3 // Dampen movement at boundaries
            lastDragValue = primaryTranslation
        } else {
            processDrag(dragDelta: dragDelta, isVertical: isVertical)
        }
    }
    
    private func handleDragEnd(_ value: DragGesture.Value) {
        isDragging = false
        resetHideUITimer()
        
        // Apply momentum-based navigation
        let momentum = dragVelocity * 0.03
        let snapThreshold: CGFloat = 50.0
        
        let isAtStart = viewModel.currentPosition == 0
        let isAtEnd = viewModel.currentPosition == viewModel.totalWords - 1
        
        if !isAtStart && !isAtEnd && abs(momentum) > snapThreshold {
            let direction: Int = momentum > 0 ? -1 : 1
            let newPos = viewModel.currentPosition + direction
            if newPos >= 0 && newPos < viewModel.totalWords {
                viewModel.seek(to: newPos)
            }
        }
        
        // Animate back to center position
        withAnimation(.interpolatingSpring(mass: 0.5, stiffness: 200, damping: 15, initialVelocity: Double(-dragVelocity / 100))) {
            visualDragOffset = 0
        }
        
        // Reset drag state
        lastDragValue = 0
        actualDragOffset = 0
        dragVelocity = 0
    }
    
    /// Processes drag input to determine word navigation
    private func processDrag(dragDelta: CGFloat, isVertical: Bool) {
        guard let centerWord = viewModel.displayWords.first(where: { $0.isCenter }) else { return }
        
        // Adjust sensitivity based on word length and velocity
        let wordLength = max(1, centerWord.text.count)
        let lengthFactor = sqrt(Double(wordLength)) / 2.0
        let baseSensitivity: CGFloat = 30.0
        let sensitivity = baseSensitivity * CGFloat(lengthFactor) / max(1, abs(dragVelocity) / 30)
        
        // Navigate if drag exceeds sensitivity threshold
        if abs(dragDelta) >= sensitivity {
            let direction: Int = dragDelta > 0 ? -1 : 1
            let newPos = viewModel.currentPosition + direction
            if newPos >= 0 && newPos < viewModel.totalWords {
                viewModel.seek(to: newPos)
                visualDragOffset = 0
                lastDragValue = 0
            }
        }
    }

    // MARK: - Text Formatting
    private var attributedContent: AttributedString {
        var result = AttributedString("")
        let separator = isVertical ? "\n" : " " // Line breaks for vertical mode
        
        for (index, word) in viewModel.displayWords.enumerated() {
            var attributedWord = AttributedString(word.text)
            
            if word.isCenter {
                // Highlight center word with different font and color
                attributedWord.font = viewModel.settings.centerFont
                attributedWord.foregroundColor = viewModel.settings.highlightColor
            } else {
                // Dim peripheral words based on settings
                attributedWord.font = viewModel.settings.actualFont
                let color = viewModel.settings.theme.textColor.opacity(viewModel.settings.peripheralBrightness)
                attributedWord.foregroundColor = color
            }
            
            result.append(attributedWord)
            
            if index < viewModel.displayWords.count - 1 {
                result.append(AttributedString(separator))
            }
        }
        return result
    }

    // MARK: - Convenience Accessor
    private var settings: AppSettings {
        viewModel.settings
    }
}
