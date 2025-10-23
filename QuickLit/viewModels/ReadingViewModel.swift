//
//  ReadingViewModel.swift
//  QuickLit
//
//  Created by Matthew Deik on 8/21/25.
//

import SwiftUI
import SwiftData
import QuartzCore
import Combine

// MARK: - ViewModel

/// Manages the RSVP reading experience, including word display, timing, and progress tracking
/// Handles the core Rapid Serial Visual Presentation logic and state management
@MainActor
class ReadingViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Array of words to display in the reading view (center + peripheral words)
    @Published var displayWords: [DisplayWord] = []
    
    /// Whether reading is currently in progress (timer active)
    @Published var isPlaying = false
    
    /// Current position in the text (word index)
    @Published var currentPosition: Int = 0
    
    /// Total number of words in the current material
    @Published var totalWords: Int = 0
    
    /// Reference to app settings for reading configuration
    @Published var settings = AppSettings() {
        didSet {
            // Restart reading with new settings if currently playing
            if isPlaying {
                restartReadingWithCurrentSettings()
            }
        }
    }
    
    // MARK: - Private Properties
    
    #if os(iOS)
    private var displayLink: CADisplayLink?              // High-precision display sync (iOS only)
    #elseif os(macOS)
    private var displayTimer: DispatchSourceTimer?       // High-precision timer (macOS)
    #endif
    
    private var scheduledWordTimes: [CFTimeInterval] = [] // Pre-calculated display times
    private var startTime: CFTimeInterval = 0            // Reading session start time
    private var currentMaterial: ReadingMaterial?        // Currently loaded reading material
    private weak var modelContext: ModelContext?         // SwiftData context for saving progress
    private var words: [String] = []                     // Array of individual words from the content
    private var settingsCancellable: AnyCancellable?     // For observing settings changes
    
    // MARK: - Display Word Structure
    
    /// Represents a word in the display with its positioning information
    struct DisplayWord: Identifiable {
        let id = UUID()
        let text: String
        let isCenter: Bool  // Whether this word is the center (focus) word
    }
    
    // MARK: - Initialization
    
    init() {
        // Observe settings changes to restart reading when WPM changes
        setupSettingsObservation()
    }
    
    // MARK: - Settings Observation
    
    private func setupSettingsObservation() {
        settingsCancellable = settings.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                // If reading is active and settings changed, restart with new settings
                if self.isPlaying {
                    self.restartReadingWithCurrentSettings()
                }
            }
    }
    
    // MARK: - Material Loading
    
    /// Loads a reading material and prepares it for reading
    /// - Parameters:
    ///   - material: The ReadingMaterial to load
    ///   - modelContext: SwiftData context for saving progress
    func loadMaterial(_ material: ReadingMaterial, modelContext: ModelContext) {
        self.modelContext = modelContext
        self.currentMaterial = material
        
        // Split content into individual words, filtering out empty strings
        words = material.content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        currentPosition = material.currentPosition
        totalWords = words.count
        updateDisplayWords()
        
        print("Loaded material: \(material.title), position: \(material.currentPosition)")
    }
    
    // MARK: - Reading Controls
    
    /// Starts the automatic reading with high-precision timing from current position
    func startReading() {
        guard !isPlaying else { return }
        
        isPlaying = true
        
        #if os(iOS)
        // iOS: Use CADisplayLink for frame-perfect timing
        setupDisplayLink()
        #elseif os(macOS)
        // macOS: Use DispatchSourceTimer for high-precision timing
        setupDisplayTimer()
        #endif
        
        // Schedule from CURRENT position, not beginning
        rescheduleFromCurrentPosition()
        
        print("Started reading at \(settings.readingSpeed) WPM from position \(currentPosition)")
    }
    
    /// Pauses the automatic reading
    func pauseReading() {
        isPlaying = false
        
        #if os(iOS)
        displayLink?.invalidate()
        displayLink = nil
        #elseif os(macOS)
        displayTimer?.cancel()
        displayTimer = nil
        #endif
        
        updateMaterialProgress() // Save current position when pausing
    }
    
    /// Restarts reading with current settings (used when settings change during reading)
    private func restartReadingWithCurrentSettings() {
        let wasPlaying = isPlaying
        pauseReading()
        
        if wasPlaying {
            // Small delay to ensure cleanup is complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.startReading()
            }
        }
    }
    
    /// Jumps to a specific position in the text
    /// - Parameter position: Target word index
    func seek(to position: Int) {
        currentPosition = min(max(0, position), words.count - 1)
        updateDisplayWords()
        updateMaterialProgress()
        
        // If playing, reschedule from new position
        if isPlaying {
            rescheduleFromCurrentPosition()
        }
    }
    
    /// Moves forward by the configured number of words
    func moveForward() {
        let newPosition = min(currentPosition + settings.wordNavigationCount, words.count - 1)
        seek(to: newPosition)
    }
    
    /// Moves backward by the configured number of words
    func moveBackward() {
        let newPosition = max(currentPosition - settings.wordNavigationCount, 0)
        seek(to: newPosition)
    }
    
    // MARK: - Platform-Specific Timing Setup
    
    #if os(iOS)
    /// Sets up CADisplayLink for iOS frame-perfect timing
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateDisplay))
        displayLink?.add(to: .main, forMode: .common)
    }
    #elseif os(macOS)
    /// Sets up high-precision DispatchSourceTimer for macOS
    private func setupDisplayTimer() {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        
        // Use ultra-high precision timing (1ms intervals) to handle 1000+ WPM
        let interval = DispatchTimeInterval.milliseconds(1)
        timer.schedule(deadline: .now(), repeating: interval)
        
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.updateDisplay()
            }
        }
        
        timer.resume()
        displayTimer = timer
    }
    #endif
    
    // MARK: - High-Precision Display Update
    
    #if os(iOS)
    /// High-precision display update synchronized with screen refresh (iOS)
    @objc private func updateDisplay() {
        performDisplayUpdate()
    }
    #elseif os(macOS)
    /// High-precision timer-based update (macOS)
    private func updateDisplay() {
        performDisplayUpdate()
    }
    #endif
    
    /// Common display update logic used by both platforms
    private func performDisplayUpdate() {
        guard isPlaying else { return }
        
        let currentTime = CACurrentMediaTime()
        
        // Find the next word that hasn't been displayed yet
        let targetPosition = scheduledWordTimes.firstIndex { $0 > currentTime } ?? words.count
        
        let newPosition = min(targetPosition, words.count - 1)
        
        if newPosition != currentPosition {
            currentPosition = newPosition
            updateDisplayWords()
            updateMaterialProgress()
            
            // Check if we've fallen behind significantly (more than 100ms)
            if currentPosition < words.count - 1 {
                let currentWordTime = scheduledWordTimes[currentPosition]
                if currentTime - currentWordTime > 0.1 {
                    print("Falling behind, rescheduling...")
                    rescheduleFromCurrentPosition()
                }
            }
        }
        
        // Check if we've reached the end
        if currentPosition >= words.count - 1 && currentTime >= scheduledWordTimes.last! {
            pauseReading()
        }
    }
    
    /// Reschedules word times from current position to recover from lag or start reading
    private func rescheduleFromCurrentPosition() {
        guard currentPosition < words.count else { return }
        
        let currentTime = CACurrentMediaTime()
        let wordInterval = 60.0 / settings.readingSpeed
        
        // Initialize array if needed
        if scheduledWordTimes.count != words.count {
            scheduledWordTimes = Array(repeating: 0.0, count: words.count)
        }
        
        // Schedule from CURRENT POSITION forward
        for i in currentPosition..<words.count {
            scheduledWordTimes[i] = currentTime + (Double(i - currentPosition) * wordInterval)
        }
        
        // For positions before current, set them to past times so they don't interfere
        for i in 0..<currentPosition {
            scheduledWordTimes[i] = currentTime - 1.0
        }
        
        startTime = currentTime - (Double(currentPosition) * wordInterval)
    }
    
    // MARK: - Private Methods
    
    /// Updates the displayWords array with current center word and peripheral words
    /// Implements smart word selection to fit words on one line when possible
    private func updateDisplayWords() {
        let maxPeripheralWords = 2
        let charLimit = settings.peripheralCharLimit
        
        var leftIndices: [Int] = []  // Indices for left peripheral words
        var rightIndices: [Int] = [] // Indices for right peripheral words
        
        let center = currentPosition
        
        // Validate center position
        guard center >= 0 && center < words.count else {
            displayWords = []
            return
        }
        
        // Start with maximum peripheral words and reduce if needed for line fitting
        var peripheralWordLimit = maxPeripheralWords
        
        while peripheralWordLimit >= 0 {
            leftIndices = []
            rightIndices = []
            var leftChars = 0  // Total characters in left words
            var rightChars = 0 // Total characters in right words
            
            // Helper to check if a word fits character limit and is within bounds
            func fits(_ idx: Int) -> Bool {
                return idx >= 0 && idx < words.count && words[idx].count <= charLimit
            }
            
            // Only try to build indices if we're allowing peripheral words
            if peripheralWordLimit > 0 {
                // Try to build left and right indices with current limit
                for i in 1...peripheralWordLimit {
                    let rIdx = center + i
                    let lIdx = center - i
                    
                    // Add right word if it fits and we have space
                    if rightIndices.count < peripheralWordLimit && fits(rIdx) {
                        rightIndices.append(rIdx)
                        rightChars += words[rIdx].count
                    }
                    
                    // Add left word if it fits and we have space
                    if leftIndices.count < peripheralWordLimit && fits(lIdx) {
                        leftIndices.append(lIdx)
                        leftChars += words[lIdx].count
                    }
                }
                
                // Find additional candidate words that weren't included initially
                var leftCandidates: [Int] = []
                var rightCandidates: [Int] = []
                
                for i in 1...peripheralWordLimit {
                    let lIdx = center - i
                    let rIdx = center + i
                    if fits(lIdx) && !leftIndices.contains(lIdx) { leftCandidates.append(lIdx) }
                    if fits(rIdx) && !rightIndices.contains(rIdx) { rightCandidates.append(rIdx) }
                }
                
                leftCandidates.sort()
                rightCandidates.sort()
                
                // Fill remaining slots while maintaining character balance
                while (leftIndices.count < peripheralWordLimit || rightIndices.count < peripheralWordLimit) {
                    let preferRight = rightChars <= leftChars // Balance character counts
                    
                    if preferRight {
                        if rightIndices.count < peripheralWordLimit, let r = rightCandidates.first {
                            rightIndices.append(r)
                            rightChars += words[r].count
                            rightCandidates.removeFirst()
                            continue
                        }
                        if leftIndices.count < peripheralWordLimit, let l = leftCandidates.first {
                            leftIndices.append(l)
                            leftChars += words[l].count
                            leftCandidates.removeFirst()
                            continue
                        }
                    } else {
                        if leftIndices.count < peripheralWordLimit, let l = leftCandidates.first {
                            leftIndices.append(l)
                            leftChars += words[l].count
                            leftCandidates.removeFirst()
                            continue
                        }
                        if rightIndices.count < peripheralWordLimit, let r = rightCandidates.first {
                            rightIndices.append(r)
                            rightChars += words[r].count
                            rightCandidates.removeFirst()
                            continue
                        }
                    }
                    break
                }
            }
            
            leftIndices.sort()
            rightIndices.sort()
            
            // Check if this word configuration would likely fit on one line
            if shouldFitOnOneLine(leftIndices: leftIndices, rightIndices: rightIndices, centerIndex: center) {
                break // Configuration works, keep it
            } else {
                // Reduce word count and try again with fewer peripheral words
                peripheralWordLimit -= 1
            }
        }
        
        // Build the final display array with proper ordering
        var displayArray: [DisplayWord] = []
        
        // Add left peripheral words
        for idx in leftIndices {
            displayArray.append(DisplayWord(text: words[idx], isCenter: false))
        }
        
        // Add center word
        displayArray.append(DisplayWord(text: words[center], isCenter: true))
        
        // Add right peripheral words
        for idx in rightIndices {
            displayArray.append(DisplayWord(text: words[idx], isCenter: false))
        }
        
        displayWords = displayArray
    }
    
    /// Determines if the current word selection should fit on one line
    /// Uses character count estimation to prevent text wrapping
    private func shouldFitOnOneLine(leftIndices: [Int], rightIndices: [Int], centerIndex: Int) -> Bool {
        guard !settings.verticalReading else {
            // In vertical mode, each word is on its own line, so wrapping isn't an issue
            return true
        }
        
        // Calculate total character count including spaces
        var totalChars = 0
        
        // Add left words with spaces
        for index in leftIndices {
            totalChars += words[index].count + 1 // +1 for space
        }
        
        // Add center word
        totalChars += words[centerIndex].count
        
        // Add right words with spaces
        for index in rightIndices {
            totalChars += words[index].count + 1 // +1 for space
        }
        
        // Estimate if this would fit on one line
        // Use conservative estimation based on typical screen width and font size
        let averageCharWidth: CGFloat = 8.0 // Approximate width per character
        let estimatedWidth = CGFloat(totalChars) * averageCharWidth * CGFloat(settings.textSize) / 17.0
        
        // Assume typical screen width minus some padding
        let maxReasonableWidth: CGFloat = 300.0
        
        return estimatedWidth <= maxReasonableWidth
    }

    /// Saves the current reading progress to persistent storage
    private func updateMaterialProgress() {
        guard let currentMaterial = currentMaterial else { return }
        if currentMaterial.currentPosition == currentPosition {
            return
        }
        // Update the position and last read date
        currentMaterial.currentPosition = currentPosition
        currentMaterial.lastReadDate = Date() // Update last read date
        
        // Save changes to persistent store with error handling
        do {
            try modelContext?.save()
        } catch {
            print("Failed to save progress: \(error)")
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        #if os(iOS)
        displayLink?.invalidate()
        #elseif os(macOS)
        displayTimer?.cancel()
        #endif
        settingsCancellable?.cancel()
    }
}
