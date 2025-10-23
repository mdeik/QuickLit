//
//  ReadingViewModelTests.swift
//  QuickLitTests
//
//  Created by Matthew Deik on 8/19/25.
//

import Testing
import SwiftData
@testable import QuickLit

@Suite("ReadingViewModel Tests")
struct ReadingViewModelTests {
    
    @Test("ViewModel loads material correctly")
    func testMaterialLoading() async throws {
        let container = try ModelContainer(for: ReadingMaterial.self, configurations: .init(isStoredInMemoryOnly: true))
        
        await MainActor.run {
            let modelContext = container.mainContext
            let material = ReadingMaterial(title: "Test", content: "Word1 word2 word3 word4 word5")
            let viewModel = ReadingViewModel()
            
            viewModel.loadMaterial(material, modelContext: modelContext)
            
            #expect(viewModel.totalWords == 5)
            #expect(viewModel.currentPosition == 0)
            #expect(!viewModel.displayWords.isEmpty)
            #expect(viewModel.isPlaying == false)
        }
    }
    
    @Test("Word navigation moves position correctly")
    func testWordNavigation() async throws {
        let container = try ModelContainer(for: ReadingMaterial.self, configurations: .init(isStoredInMemoryOnly: true))
        
        await MainActor.run {
            let modelContext = container.mainContext
            let material = ReadingMaterial(title: "Test", content: "One two three four five")
            let viewModel = ReadingViewModel()
            
            viewModel.loadMaterial(material, modelContext: modelContext)
            
            // Test forward navigation
            viewModel.moveForward()
            #expect(viewModel.currentPosition == 1)
            
            // Test backward navigation
            viewModel.moveBackward()
            #expect(viewModel.currentPosition == 0)
            
            // Test seek
            viewModel.seek(to: 3)
            #expect(viewModel.currentPosition == 3)
        }
    }
    
    @Test("Seek respects bounds")
    func testSeekBounds() async throws {
        let container = try ModelContainer(for: ReadingMaterial.self, configurations: .init(isStoredInMemoryOnly: true))
        
        await MainActor.run {
            let modelContext = container.mainContext
            let material = ReadingMaterial(title: "Test", content: "One two three")
            let viewModel = ReadingViewModel()
            
            viewModel.loadMaterial(material, modelContext: modelContext)
            
            // Test seek below lower bound
            viewModel.seek(to: -5)
            #expect(viewModel.currentPosition == 0)
            
            // Test seek above upper bound
            viewModel.seek(to: 10)
            #expect(viewModel.currentPosition == 2) // "One", "two", "three" -> 3 words, positions 0-2
        }
    }
    
    @Test("Play/pause functionality")
    func testPlayPause() async throws {
        let container = try ModelContainer(for: ReadingMaterial.self, configurations: .init(isStoredInMemoryOnly: true))
        
        await MainActor.run {
            let modelContext = container.mainContext
            let material = ReadingMaterial(title: "Test", content: "Content")
            let viewModel = ReadingViewModel()
            
            viewModel.loadMaterial(material, modelContext: modelContext)
            
            // Start reading
            viewModel.startReading()
            #expect(viewModel.isPlaying == true)
            
            // Pause reading
            viewModel.pauseReading()
            #expect(viewModel.isPlaying == false)
        }
    }
    
    @Test("Display words structure")
    func testDisplayWords() async throws {
        let container = try ModelContainer(for: ReadingMaterial.self, configurations: .init(isStoredInMemoryOnly: true))
        
        await MainActor.run {
            let modelContext = container.mainContext
            let material = ReadingMaterial(title: "Test", content: "First second third fourth fifth")
            let viewModel = ReadingViewModel()
            
            viewModel.loadMaterial(material, modelContext: modelContext)
            
            let displayWords = viewModel.displayWords
            #expect(!displayWords.isEmpty)
            
            // Should have exactly one center word
            let centerWords = displayWords.filter { $0.isCenter }
            #expect(centerWords.count == 1)
            
            // Center word should be at the correct position
            if let centerWord = centerWords.first {
                #expect(centerWord.text == "First")
            }
        }
    }
}
