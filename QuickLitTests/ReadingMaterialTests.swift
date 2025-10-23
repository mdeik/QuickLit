//
//  ReadingMaterialTests.swift
//  QuickLit
//
//  Created by Matthew Deik on 10/18/25.
//


//
//  ReadingMaterialTests.swift
//  QuickLitTests
//
//  Created by Matthew Deik on 8/19/25.
//

import Testing
import SwiftData
@testable import QuickLit
import Foundation

@Suite("ReadingMaterial Tests")
struct ReadingMaterialTests {
    
    @Test("ReadingMaterial initialization with title and content")
    func testInitialization() {
        let title = "Test Material"
        let content = "This is test content with multiple words."
        let material = ReadingMaterial(title: title, content: content)
        
        #expect(material.title == title)
        #expect(material.content == content)
        #expect(material.currentPosition == 0)
        #expect(material.wordCount == 7)
        #expect(material.createdAt <= Date())
        #expect(material.lastReadDate <= Date())
    }
    
    @Test("Word count calculation with empty content")
    func testWordCountEmpty() {
        let material = ReadingMaterial(title: "Empty", content: "")
        #expect(material.wordCount == 0)
    }
    
    @Test("Word count calculation with whitespace only")
    func testWordCountWhitespace() {
        let material = ReadingMaterial(title: "Whitespace", content: "   \n\t  ")
        #expect(material.wordCount == 0)
    }
    
    @Test("Word count calculation with normal text")
    func testWordCountNormalText() {
        let testCases: [(String, Int)] = [
            ("Single", 1),
            ("Two words", 2),
            ("This has four words", 4),
            ("Multiple   spaces   between", 3),
            ("Line\nbreaks\ncount", 3),
            ("Punctuation, doesn't affect; word count!", 5)
        ]
        
        for (content, expectedCount) in testCases {
            let material = ReadingMaterial(title: "Test", content: content)
            #expect(material.wordCount == expectedCount, 
                   "Expected \(expectedCount) words for '\(content)', got \(material.wordCount)")
        }
    }
    
    @Test("ReadingMaterial with custom position")
    func testCustomPosition() {
        let material = ReadingMaterial(title: "Test", content: "Content", currentPosition: 5)
        #expect(material.currentPosition == 5)
    }
    
    @Test("Dates are set appropriately on initialization")
    func testDateInitialization() {
        let beforeCreation = Date()
        let material = ReadingMaterial(title: "Test", content: "Content")
        let afterCreation = Date()
        
        #expect(material.createdAt >= beforeCreation)
        #expect(material.createdAt <= afterCreation)
        #expect(material.lastReadDate >= beforeCreation)
        #expect(material.lastReadDate <= afterCreation)
    }
}
