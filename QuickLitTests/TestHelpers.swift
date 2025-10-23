//
//  TestHelpers.swift
//  QuickLit
//
//  Created by Matthew Deik on 10/18/25.
//


//
//  TestHelpers.swift
//  QuickLitTests
//
//  Created by Matthew Deik on 8/19/25.
//

import Foundation
import Testing
@testable import QuickLit

/// Test helpers and utilities for QuickLit tests
struct TestHelpers {
    
    /// Creates a temporary directory for test files
    static func createTempDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuickLitTests-\(UUID().uuidString)")
        
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    /// Cleans up a temporary directory
    static func cleanupTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    /// Creates a test file with given content and extension
    static func createTestFile(content: String, fileExtension: String, in directory: URL) -> URL {
        let fileName = "testfile-\(UUID().uuidString).\(fileExtension)"
        let fileURL = directory.appendingPathComponent(fileName)
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            fatalError("Failed to create test file: \(error)")
        }
    }
    
    /// Sample text content for testing
    static let sampleTextContent = """
    This is a sample text file for testing QuickLit.
    It contains multiple lines and various types of content.
    
    QuickLit is an RSVP reader that helps you read faster.
    RSVP stands for Rapid Serial Visual Presentation.
    
    The quick brown fox jumps over the lazy dog.
    """
    
    /// Creates sample files for all supported formats in a directory
    static func createSampleFiles(in directory: URL) -> [String: URL] {
        var files: [String: URL] = [:]
        
        // Plain text
        files["txt"] = createTestFile(content: sampleTextContent, fileExtension: "txt", in: directory)
        
        return files
    }
}
