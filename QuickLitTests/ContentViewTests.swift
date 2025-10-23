//
//  ContentViewTests.swift
//  QuickLitTests
//
//  Created by Matthew Deik on 8/19/25.
//

import Testing
import SwiftData
@testable import QuickLit

@Suite("ContentView Tests")
struct ContentViewTests {
    
    @Test("Sample content addition on first launch")
    func testSampleContentAddition() async throws {
        // This would test the first launch experience
        // In a real test, we'd need to mock UserDefaults and check the logic
        
        // For now, we can test the sample content creation method
        _ = try ModelContainer(for: ReadingMaterial.self, configurations: .init(isStoredInMemoryOnly: true))
        
        // We'd typically test this through the ContentView, but for unit testing
        // we can test the helper method directly if it were accessible
    }
    
    @Test("Material deletion functionality")
    func testMaterialDeletion() async throws {
        let container = try ModelContainer(for: ReadingMaterial.self, configurations: .init(isStoredInMemoryOnly: true))
        
        await MainActor.run {
            let modelContext = container.mainContext
            let material = ReadingMaterial(title: "Test Delete", content: "Content")
            modelContext.insert(material)
            
            // Verify material exists
            let fetchDescriptor = FetchDescriptor<ReadingMaterial>()
            let materialsBefore = try? modelContext.fetch(fetchDescriptor)
            #expect(materialsBefore?.contains(where: { $0.title == "Test Delete" }) == true)
            
            // Delete material
            modelContext.delete(material)
            try? modelContext.save()
            
            // Verify material is gone
            let materialsAfter = try? modelContext.fetch(fetchDescriptor)
            #expect(materialsAfter?.contains(where: { $0.title == "Test Delete" }) == false)
        }
    }
    
    @Test("String filename sanitization")
    func testFilenameSanitization() {
        let testCases: [(String, String)] = [
            ("normal.txt", "normal.txt"),
            ("file/with/slashes.txt", "file_with_slashes.txt"),
            ("file\\with\\backslashes.txt", "file_with_backslashes.txt"),
            ("file?with?question.txt", "file_with_question.txt"),
            ("file*with*stars.txt", "file_with_stars.txt"),
            ("file|with|pipe.txt", "file_with_pipe.txt"),
            ("file\"with\"quotes.txt", "file_with_quotes.txt"),
            ("file<with>angles.txt", "file_with_angles.txt"),
        ]
        
        for (input, expected) in testCases {
            let result = input.sanitizedFileName
            #expect(result == expected,
                   "Expected '\(expected)' for '\(input)', got '\(result)'")
        }
    }
}
