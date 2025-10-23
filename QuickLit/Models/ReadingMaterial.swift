//
//  ReadingMaterial.swift
//  QuickLit
//
//  Created by Matthew Deik on 8/21/25.
//

import SwiftData
import Foundation

// MARK: - Data Model

/// Represents a reading material/document in the QuickLit app
/// Uses SwiftData for persistence and stores reading progress
@Model
final class ReadingMaterial {
    var id: UUID
    var title: String
    var content: String
    var currentPosition: Int  // Current reading position (word index)
    var createdAt: Date
    var lastReadDate: Date    // Timestamp of last reading session
    var wordCount: Int        // Pre-calculated word count for display
    
    // EPUB chapter support
    var chapterData: Data?    // Serialized chapter information for EPUB files
    
    /// Initialize a new reading material with content
    /// - Parameters:
    ///   - title: The title of the reading material
    ///   - content: The text content to be read
    ///   - currentPosition: Starting position (defaults to 0)
    ///   - chapters: Optional chapter information for EPUB files
    init(title: String, content: String, currentPosition: Int = 0, chapters: [EPUBChapter]? = nil) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.currentPosition = currentPosition
        self.createdAt = Date()
        self.lastReadDate = Date() // Initialize with current date
        
        // Pre-calculate word count for performance and display
        let words = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        self.wordCount = words.count
        
        // Store chapter information if provided
        self.chapterData = serializeChapters(chapters)
    }
    
    /// Get chapter information for EPUB files
    var chapters: [EPUBChapter]? {
        guard let data = chapterData else { return nil }
        return deserializeChapters(from: data)
    }
    
    /// Set chapter information for EPUB files
    func setChapters(_ chapters: [EPUBChapter]?) {
        self.chapterData = serializeChapters(chapters)
    }
    
    /// Serialize chapters to Data for storage
    private func serializeChapters(_ chapters: [EPUBChapter]?) -> Data? {
        guard let chapters = chapters else { return nil }
        
        let chapterDicts = chapters.map { chapter in
            return [
                "title": chapter.title,
                "startPosition": chapter.startPosition,
                "href": chapter.href
            ]
        }
        
        return try? JSONSerialization.data(withJSONObject: chapterDicts)
    }
    
    /// Deserialize chapters from Data
    private func deserializeChapters(from data: Data) -> [EPUBChapter]? {
        guard let chapterDicts = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }
        
        return chapterDicts.compactMap { dict in
            guard let title = dict["title"] as? String,
                  let startPosition = dict["startPosition"] as? Int,
                  let href = dict["href"] as? String else {
                return nil
            }
            
            // Create EPUBChapter (note: ID will be regenerated, which is fine)
            return EPUBChapter(title: title, startPosition: startPosition, href: href)
        }
    }
}
