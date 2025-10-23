//
//  SupportedFormat.swift
//  QuickLit
//
//  Created by Matthew Deik on 10/9/25.
//
// Handles file format detection and text extraction for imported documents

import Foundation
import ZIPFoundation
import SwiftSoup
import PDFKit
import UniformTypeIdentifiers

// MARK: - Chapter Information Model

/// Represents a chapter in an EPUB file with its position and title
struct EPUBChapter: Identifiable, Equatable, Codable {
    let id = UUID()
    let title: String
    let startPosition: Int // Word index where chapter starts
    let href: String // Original file path for reference
    
    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case title, startPosition, href
    }
}

/// Enhanced result for EPUB extraction containing both text and chapter information
struct EPUBExtractionResult {
    let fullText: String
    let chapters: [EPUBChapter]
}

/// Enum representing supported document formats in the application
enum SupportedFormat {
    case plainText
    case rtf
    case docX
    case epub
    case pdf
    case html
    case fb2
    case odt
    
    /// Static array containing information about all supported file formats
    /// Each tuple includes: format enum, file extensions, and UTType
    static let supportedFileInfo: [(format: SupportedFormat, extensions: [String], utType: UTType)] = [
        (.plainText, ["txt"], .plainText),
        (.rtf, ["rtf"], .rtf),
        (.docX, ["docx"], UTType(filenameExtension: "docx")!),
        (.epub, ["epub"], UTType(filenameExtension: "epub")!),
        (.pdf, ["pdf"], .pdf),
        (.html, ["html", "htm"], .html),
        (.fb2, ["fb2"], UTType(filenameExtension: "fb2")!),
        (.odt, ["odt"], UTType(filenameExtension: "odt")!)
    ]
    
    /// Array of all supported file extensions (lowercase)
    static var supportedExtensions: [String] {
        supportedFileInfo.flatMap { $0.extensions }
    }
    
    /// Array of all supported UTTypes for file import
    static var allowedUTTypes: [UTType] {
        supportedFileInfo.map { $0.utType }
    }
    
    /// Human-readable string of supported extensions for display
    /// Formats the list with proper English grammar (commas and "or")
    static var supportedExtensionsDisplay: String {
        let ext = supportedExtensions.map { $0.uppercased() }
        
        func list(_ slice: ArraySlice<String>) -> String {
            switch slice.count {
            case 0: return ""
            case 1: return slice.first!
            case 2: return slice.first! + " or " + slice.last!
            default:
                return slice.dropLast().joined(separator: ", ") + ", or " + slice.last!
            }
        }
        
        let combined = list(ArraySlice(ext))
        return combined
    }

    /// Array of strings for displaying supported extensions across multiple lines
    /// Splits the extensions roughly in half for better visual layout
    static var supportedExtensionsDisplayLines: [String] {
        let uppercaseExtensions = supportedExtensions.map { $0.uppercased() }
        
        let mid = (uppercaseExtensions.count + 1) / 2
        let firstLine = uppercaseExtensions[0..<mid].joined(separator: ", ")
        let secondLine = uppercaseExtensions[mid...].joined(separator: ", ")
        
        return [firstLine, secondLine]
    }
    
    /// Initialize SupportedFormat from a URL by checking its file extension
    /// - Parameter url: The file URL to check
    /// - Returns: SupportedFormat if extension is recognized, nil otherwise
    init?(url: URL) {
        let fileExtension = url.pathExtension.lowercased()
        for (format, extensions, _) in SupportedFormat.supportedFileInfo {
            if extensions.contains(fileExtension) {
                self = format
                return
            }
        }
        return nil
    }
    
    /// Extract plain text from a file URL based on the format
    /// - Parameter url: The file URL to extract text from
    /// - Returns: Plain text content as String
    /// - Throws: PlainTextError if extraction fails
    func plainText(from url: URL) throws -> String {
        switch self {
        case .plainText:
            // Direct UTF-8 text file reading
            return try String(contentsOf: url, encoding: .utf8)
            
        case .rtf:
            // Use NSAttributedString to parse RTF format
            let attr = try NSAttributedString(
                url: url,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
            return attr.string
            
        case .docX:
            // DOCX is a ZIP archive containing XML documents
            return try extractDOCXText(from: url)
            
        case .epub:
            // EPUB is a ZIP archive with specific structure and XHTML content
            let result = try extractEPUBTextWithChapters(from: url)
            return result.fullText
            
        case .pdf:
            // Use PDFKit to extract text from PDF pages
            return try extractPDFText(from: url)
            
        case .html:
            // Parse HTML and remove script/style tags
            return try extractHTMLText(from: url)
            
        case .fb2:
            // FictionBook format - XML-based e-book format
            return try extractFB2Text(from: url)
            
        case .odt:
            // OpenDocument Text format - ZIP archive with XML content
            return try extractODTText(from: url)
        }
    }
    
    /// Extract EPUB text with chapter information
    /// - Parameter url: The EPUB file URL
    /// - Returns: EPUBExtractionResult containing text and chapters
    /// - Throws: PlainTextError if extraction fails
    func extractEPUBWithChapters(from url: URL) throws -> EPUBExtractionResult {
        guard case .epub = self else {
            throw PlainTextError.unsupportedFormat
        }
        return try extractEPUBTextWithChapters(from: url)
    }
    
    // MARK: - EPUB helpers

    /// Extract text and chapter information from EPUB file
    private func extractEPUBTextWithChapters(from url: URL) throws -> EPUBExtractionResult {
        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            throw PlainTextError.badArchive
        }
        
        // Find the OPF file path from container.xml
        let containerEntry = try archive.entry(for: "META-INF/container.xml")
        let containerData = try archive.extract(containerEntry)
        let opfPath = try findOPFPath(in: containerData)
        
        // Parse the OPF file to get spine information
        let opfEntry = try archive.entry(for: opfPath)
        let opfData = try archive.extract(opfEntry)
        
        let base = (opfPath as NSString).deletingLastPathComponent
        let spineItemIDs = try findSpineItemIDs(in: opfData)
        
        // Extract text and chapter information from each spine item
        var fullText = ""
        var chapters: [EPUBChapter] = []
        var currentWordPosition = 0
        var existingChapterTitles = Set<String>() // Track existing chapter titles

        for id in spineItemIDs {
            guard let (href, title) = try findItemHrefAndTitle(in: opfData, for: id) else { continue }
            
            // Skip navigation elements
            if isNavigationItem(href, title: title) {
                continue
            }
            
            let chapterPath = (base as NSString).appendingPathComponent(href)
            guard let entry = archive.entry(forPath: chapterPath) else { continue }
            
            let xhtml = try archive.extract(entry)
            let doc = try SwiftSoup.parse(String(decoding: xhtml, as: UTF8.self))
            
            // Remove script and style elements
            try doc.select("script, style").remove()
            
            // Extract chapter title - try to find the best title
            let chapterTitle = try extractChapterTitle(from: doc, fallback: href)
            
            // Skip specific chapters and their contents
            if shouldSkipChapter(chapterTitle, href: href) {
                continue
            }
            
            // Get the text content for this chapter WITHOUT the title
            let chapterText = try extractContentWithoutTitle(from: doc, chapterTitle: chapterTitle)
            let trimmedText = chapterText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip if no content
            guard !trimmedText.isEmpty else { continue }
            
            // Check if this is a continuation file using existing chapter titles
            let isContinuationFile = isContinuationChapter(chapterTitle, href: href, existingChapterTitles: existingChapterTitles)
            
            if isContinuationFile {
                // This is a continuation file - append to previous chapter
                if !fullText.isEmpty {
                    fullText += "\n\n"
                }
                fullText += chapterText
                
                // Update word position for the existing chapter
                let words = chapterText.components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                currentWordPosition += words.count
                
                // Don't create a new chapter for continuation files
            } else {
                // Regular chapter - create new chapter entry
                let chapter = EPUBChapter(
                    title: chapterTitle,
                    startPosition: currentWordPosition,
                    href: href
                )
                chapters.append(chapter)
                existingChapterTitles.insert(chapterTitle) // Add to existing titles
                
                // Append chapter text to full text
                if !fullText.isEmpty {
                    fullText += "\n\n"
                }
                fullText += chapterText
                
                // Update word position for next chapter
                let words = chapterText.components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                currentWordPosition += words.count
            }
        }
        
        return EPUBExtractionResult(fullText: fullText, chapters: chapters)
    }

    /// Extract content from document without including the chapter title
    private func extractContentWithoutTitle(from doc: Document, chapterTitle: String) throws -> String {
        // Try to remove the title element if we can find it
        let titleSelectors = [
            "h1.chapter-title", "h2.chapter-title", "h3.chapter-title",
            ".chapter-title", ".chaptertitle", ".title-chapter",
            "h1.title", "h2.title", "h3.title",
            ".chapter h1", ".chapter h2", ".chapter h3",
            "section[epub\\:type='chapter'] h1", "section[epub\\:type='chapter'] h2"
        ]
        
        // Remove title elements that match common patterns
        for selector in titleSelectors {
            if let titleElement = try? doc.select(selector).first(),
               let elementText = try? titleElement.text(),
               cleanTitleText(elementText) == chapterTitle {
                try titleElement.remove()
                break // Remove only the first matching title element
            }
        }
        
        // Also try to remove headings that match the chapter title
        let headings = try doc.select("title, h1, h2, h3, h4, h5, h6")
        for heading in headings {
            if let headingText = try? heading.text(),
               cleanTitleText(headingText) == chapterTitle {
                try heading.remove()
                break // Remove only the first matching heading
            }
        }
        
        // Get the remaining text content
        return try doc.text()
    }
    
    /// Check if a chapter is a continuation file (should be appended to previous chapter)
    private func isContinuationChapter(_ chapterTitle: String, href: String, existingChapterTitles: Set<String>) -> Bool {
        // Common patterns for continuation files
        let continuationPatterns = [
            #"(?i)^text/"#,  // Starts with "text/"
        ]
        
        // Check against continuation patterns
        for pattern in continuationPatterns {
            if chapterTitle.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        // Check if this exact chapter title already exists
        if existingChapterTitles.contains(chapterTitle) {
            return true
        }
        
        // Check if this is an existing chapter title that ends with " Image"
        let imageSuffixPattern = #"[^a-zA-Z0-9]+Image$"#
        if let range = chapterTitle.range(of: imageSuffixPattern,
                                          options: [.regularExpression, .caseInsensitive]) {
            let baseTitle = String(chapterTitle[..<range.lowerBound])
            if existingChapterTitles.contains(baseTitle) {
                return true
            }
        }
        return false
    }

    /// Check if a chapter should be skipped based on its title or href
    private func shouldSkipChapter(_ chapterTitle: String, href: String) -> Bool {
        let skipPatterns = [
            #"(?i)(tableofcontents|toc|table of contents)"#,
            #"(?i)(color inserts)"#,
            #"(?i)(table of contents page)"#,
            #"(?i)(title page)"#,
            #"(?i)(copyrights and credits)"#,
            #"(?i)(newsletter)"#
        ]
        
        for pattern in skipPatterns {
            if chapterTitle.range(of: pattern, options: .regularExpression) != nil ||
               href.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }

    /// Extract book title from OPF data
    private func extractBookTitle(from opfData: Data) throws -> String? {
        let parser = XMLParser(data: opfData)
        let delegate = BookTitleXMLParser()
        parser.delegate = delegate
        parser.parse()
        
        return delegate.bookTitle
    }
    
    /// XML parser delegate for extracting book title from OPF metadata
    private class BookTitleXMLParser: NSObject, XMLParserDelegate {
        var bookTitle: String?
        private var inTitle = false
        private var currentText = ""
        
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            if elementName == "dc:title" || elementName == "title" {
                inTitle = true
                currentText = ""
            }
        }
        
        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            if elementName == "dc:title" || elementName == "title" {
                inTitle = false
                let trimmedTitle = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedTitle.isEmpty && bookTitle == nil {
                    bookTitle = trimmedTitle
                }
            }
        }
        
        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if inTitle {
                currentText += string
            }
        }
    }
    
    /// Extract chapter title from XHTML document
    private func extractChapterTitle(from doc: Document, fallback: String) throws -> String {
        // Strategy 1: Look for chapter title in specific class patterns
        if let chapterTitle = try? extractTitleFromCommonPatterns(in: doc) {
            return chapterTitle
        }
        
        // Strategy 2: Look for chapter number patterns
        if let numberedTitle = try? extractNumberedChapterTitle(in: doc) {
            return numberedTitle
        }
        
        // Strategy 3: Look for the first meaningful heading that's not the book title
        if let headingTitle = try? extractHeadingTitle(in: doc) {
            return headingTitle
        }
        
        // Strategy 4: Check the document title tag
        if let titleTag = try? doc.title(),
           !titleTag.isEmpty,
           !isLikelyBookTitle(titleTag) {
            return cleanTitleText(titleTag)
        }
        
        // Strategy 5: Use filename without extension as fallback
        let fileName = (fallback as NSString).deletingPathExtension
        return fileName.isEmpty ? "Chapter" : fileName
    }
    
    /// Extract title from common CSS class patterns used in EPUBs
    private func extractTitleFromCommonPatterns(in doc: Document) throws -> String? {
        // Common class patterns for chapter titles
        let titleSelectors = [
            "h1.chapter-title", "h2.chapter-title", "h3.chapter-title",
            ".chapter-title", ".chaptertitle", ".title-chapter",
            "h1.title", "h2.title", "h3.title",
            ".chapter h1", ".chapter h2", ".chapter h3",
            "section[epub\\:type='chapter'] h1", "section[epub\\:type='chapter'] h2"
        ]
        
        for selector in titleSelectors {
            if let element = try? doc.select(selector).first(),
               let text = try? element.text(),
               !text.isEmpty && !isLikelyBookTitle(text) {
                return cleanTitleText(text)
            }
        }
        
        return nil
    }
    
    /// Extract numbered chapter titles (like "CHAPTER 1" followed by actual title)
    private func extractNumberedChapterTitle(in doc: Document) throws -> String? {
        // Look for chapter number patterns
        let chapterNumberSelectors = [
            "h1.chapter-number", ".chapter-number", ".chapternumber",
            "h1:contains(CHAPTER)", "h1:contains(Chapter)", "h1:contains(PROLOGUE)", "h1:contains(Prologue)"
        ]
        
        for selector in chapterNumberSelectors {
            if let numberElement = try? doc.select(selector).first() {
                // Look for the next h1 with class chapter-title (common pattern)
                if let nextTitle = try? numberElement.nextElementSibling(),
                   nextTitle.tagName().hasPrefix("h"),
                   let titleText = try? nextTitle.text(),
                   !titleText.isEmpty && !isLikelyBookTitle(titleText) {
                    return cleanTitleText(titleText)
                }
                
                // If no next title, try to find any h1.chapter-title in the document
                if let titleElement = try? doc.select("h1.chapter-title").first(),
                   let titleText = try? titleElement.text(),
                   !titleText.isEmpty && !isLikelyBookTitle(titleText) {
                    return cleanTitleText(titleText)
                }
                
                // If this is a prologue element, return "Prologue"
                if let elementText = try? numberElement.text(),
                   elementText.range(of: #"(?i)prologue"#, options: .regularExpression) != nil {
                    return "Prologue"
                }
            }
        }
        
        return nil
    }
    
    /// Extract title from headings, avoiding book titles
    private func extractHeadingTitle(in doc: Document) throws -> String? {
        // Get all headings in order
        let headings = try doc.select("h1, h2, h3, h4, h5, h6")
        
        for heading in headings {
            if let text = try? heading.text(),
               !text.isEmpty,
               !isLikelyBookTitle(text),
               !isChapterNumber(text) {
                
                // Special case for prologue
                if text.range(of: #"(?i)prologue"#, options: .regularExpression) != nil {
                    return "Prologue"
                }
                
                return cleanTitleText(text)
            }
        }
        
        return nil
    }
    
    /// Check if text is likely a book title rather than chapter title
    private func isLikelyBookTitle(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Common indicators of book titles in chapter files
        let bookTitleIndicators = [
            // Length-based: book titles are often shorter
            trimmed.count < 3 || trimmed.count > 100,
            // Contains common book title patterns (excluding prologue/epilogue which are valid chapters)
            trimmed.range(of: #"(?i)^(foreword|afterword|introduction|preface|appendix|index|glossary)$"#, options: .regularExpression) != nil,
            // Looks like metadata rather than chapter content
            trimmed.range(of: #"(?i)(copyright|published by|all rights|by .*|author[s]?)"#, options: .regularExpression) != nil,
            // Contains only numbers or very generic text
            trimmed.range(of: #"^\d+$"#, options: .regularExpression) != nil,
            trimmed.lowercased() == "chapter",
            trimmed.lowercased() == "part"
        ]
        
        return bookTitleIndicators.contains(true)
    }
    
    /// Check if text is just a chapter number
    private func isChapterNumber(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Patterns that indicate this is just a chapter number, not a title
        let numberPatterns = [
            #"^(CHAPTER|Chapter|CHAP|Chap)?\s*\d+$"#,
            #"^\d+$"#,
            #"^(CHAPTER|Chapter)\s+\d+\s*:?$"#,
            #"^Part\s+\d+$"#
        ]
        
        for pattern in numberPatterns {
            if trimmed.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    /// Clean up title text by removing extra whitespace and common artifacts
    private func cleanTitleText(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove HTML entities and common formatting artifacts
        cleaned = cleaned.replacingOccurrences(of: "&nbsp;", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "&#160;", with: " ")
        
        // Collapse multiple spaces
        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }
        
        // Remove trailing/leading punctuation
        cleaned = cleaned.trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
        
        return cleaned
    }
    
    /// Check if an item is likely a navigation element rather than content
    private func isNavigationItem(_ href: String, title: String) -> Bool {
        let navPatterns = [
            #"(?i)(toc|tableofcontents|nav|navigation|index)"#,
            #"(?i)(cover|titlepage)"#,
            #"(?i)(copyright|legal|notice)"#,
            #"(?i)(color inserts)"#,
            #"(?i)(table of contents page)"#,
            #"(?i)(title page)"#,
            #"(?i)(copyrights and credits)"#,
            #"(?i)(newsletter)"#
        ]
        
        for pattern in navPatterns {
            if href.range(of: pattern, options: .regularExpression) != nil ||
               title.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    /// Find the OPF file path in EPUB container data
    private func findOPFPath(in containerData: Data) throws -> String {
        let parser = XMLParser(data: containerData)
        let delegate = ContainerXMLParser()
        parser.delegate = delegate
        parser.parse()
        
        guard let opfPath = delegate.opfPath else {
            throw PlainTextError.badArchive
        }
        return opfPath
    }
    
    /// Find spine item IDs from OPF data to determine reading order
    private func findSpineItemIDs(in opfData: Data) throws -> [String] {
        let parser = XMLParser(data: opfData)
        let delegate = OPFXMLParser()
        parser.delegate = delegate
        parser.parse()
        
        return delegate.spineItemIDs
    }
    
    /// Find the href for a specific item ID in OPF data
    private func findItemHref(in opfData: Data, for itemID: String) throws -> String? {
        let parser = XMLParser(data: opfData)
        let delegate = ItemHrefXMLParser(itemID: itemID)
        parser.delegate = delegate
        parser.parse()
        
        return delegate.href
    }
    
    /// Find item href and title in OPF data
    private func findItemHrefAndTitle(in opfData: Data, for itemID: String) throws -> (href: String, title: String)? {
        let parser = XMLParser(data: opfData)
        let delegate = ItemHrefAndTitleXMLParser(itemID: itemID)
        parser.delegate = delegate
        parser.parse()
        
        return delegate.result
    }
    
    // MARK: - PDF helpers
    
    /// Extract text from PDF using PDFKit
    private func extractPDFText(from url: URL) throws -> String {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw PlainTextError.badArchive
        }
        
        var fullText = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            guard let pageText = page.string else { continue }
            fullText += pageText + "\n\n"
        }
        
        return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - HTML helpers
    
    /// Extract text from HTML file by parsing and removing non-content elements
    private func extractHTMLText(from url: URL) throws -> String {
        let htmlContent = try String(contentsOf: url, encoding: .utf8)
        let doc = try SwiftSoup.parse(htmlContent)
        try doc.select("script, style, nav, header, footer").remove()
        return try doc.text()
    }
    
    // MARK: - DOCX helpers
    
    /// Extract text from DOCX file (ZIP archive with document.xml)
    private func extractDOCXText(from url: URL) throws -> String {
        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            throw PlainTextError.badArchive
        }
        
        let documentEntry = try archive.entry(for: "word/document.xml")
        let documentData = try archive.extract(documentEntry)
        
        let parser = XMLParser(data: documentData)
        let delegate = DOCXXMLParser()
        parser.delegate = delegate
        parser.parse()
        
        return delegate.text
    }
    
    // MARK: - FB2 helpers
    
    /// Extract text from FictionBook (FB2) format
    private func extractFB2Text(from url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        
        let parser = XMLParser(data: data)
        let delegate = FB2XMLParser()
        parser.delegate = delegate
        parser.parse()
        
        guard !delegate.sections.isEmpty else {
            throw PlainTextError.badArchive
        }
        
        return delegate.sections.joined(separator: "\n\n")
    }
    
    // MARK: - ODT helpers
    
    /// Extract text from OpenDocument Text (ODT) format
    private func extractODTText(from url: URL) throws -> String {
        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            throw PlainTextError.badArchive
        }
        
        let contentEntry = try archive.entry(for: "content.xml")
        let contentData = try archive.extract(contentEntry)
        
        let parser = XMLParser(data: contentData)
        let delegate = ODTXMLParser()
        parser.delegate = delegate
        parser.parse()
        
        guard !delegate.paragraphs.isEmpty else {
            throw PlainTextError.badArchive
        }
        
        return delegate.paragraphs.joined(separator: "\n\n")
    }
    
    /// Error types for text extraction failures
    enum PlainTextError: LocalizedError {
        case unsupportedYet, badArchive, unsupportedFormat
        
        var errorDescription: String? {
            switch self {
            case .unsupportedYet: return "This format support is coming soon."
            case .badArchive:     return "The file could not be opened or processed."
            case .unsupportedFormat: return "The file format is not supported or the file is corrupted."
            }
        }
    }
}

// MARK: - XML Parser Delegates

/// XML parser delegate for finding OPF path in EPUB container
private class ContainerXMLParser: NSObject, XMLParserDelegate {
    var opfPath: String?
    private var currentElement = ""
    private var inRootfile = false
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        
        if elementName == "rootfile" && attributeDict["media-type"] == "application/oebps-package+xml" {
            opfPath = attributeDict["full-path"]
        }
    }
}

/// XML parser delegate for extracting spine information from OPF
private class OPFXMLParser: NSObject, XMLParserDelegate {
    var spineItemIDs: [String] = []
    private var inSpine = false
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "spine" {
            inSpine = true
        } else if inSpine && elementName == "itemref" {
            if let idref = attributeDict["idref"] {
                spineItemIDs.append(idref)
            }
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "spine" {
            inSpine = false
        }
    }
}

/// XML parser delegate for finding specific item href in OPF
private class ItemHrefXMLParser: NSObject, XMLParserDelegate {
    let targetItemID: String
    var href: String?
    
    init(itemID: String) {
        self.targetItemID = itemID
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "item", let id = attributeDict["id"], id == targetItemID {
            href = attributeDict["href"]
        }
    }
}

/// XML parser delegate for extracting item href and title from OPF
private class ItemHrefAndTitleXMLParser: NSObject, XMLParserDelegate {
    let targetItemID: String
    var result: (href: String, title: String)?
    
    private var currentElement = ""
    private var currentAttributes: [String: String] = [:]
    private var foundTarget = false
    private var currentTitle = ""
    private var inMetadata = false
    private var isNavElement = false
    
    init(itemID: String) {
        self.targetItemID = itemID
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentAttributes = attributeDict
        
        if elementName == "item", let id = attributeDict["id"], id == targetItemID {
            foundTarget = true
            if let href = attributeDict["href"] {
                let title = attributeDict["title"] ?? ""
                result = (href: href, title: title)
                currentTitle = title
            }
        } else if elementName == "metadata" {
            inMetadata = true
        } else if elementName == "nav" {
            isNavElement = true
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if foundTarget && result != nil {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && currentTitle.isEmpty && !isNavElement {
                // Only use text content if it's meaningful and not navigation
                currentTitle = trimmed
                result?.title = currentTitle
            }
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" && foundTarget {
            // Stop parsing once we found our target
            parser.abortParsing()
        } else if elementName == "metadata" {
            inMetadata = false
        } else if elementName == "nav" {
            isNavElement = false
        }
    }
}

/// XML parser delegate for extracting text from DOCX document.xml
private class DOCXXMLParser: NSObject, XMLParserDelegate {
    var text = ""
    private var inParagraph = false
    private var currentText = ""
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "w:p" {
            inParagraph = true
            currentText = ""
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "w:p" {
            inParagraph = false
            if !currentText.isEmpty {
                if !text.isEmpty {
                    text += "\n\n"
                }
                text += currentText
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inParagraph {
            currentText += string
        }
    }
}

/// XML parser delegate for extracting text from FB2 format
private class FB2XMLParser: NSObject, XMLParserDelegate {
    var sections: [String] = []
    private var currentSection = ""
    private var inParagraph = false
    private var currentText = ""
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "p" {
            inParagraph = true
            currentText = ""
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "p" {
            inParagraph = false
            let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                if !currentSection.isEmpty {
                    currentSection += "\n\n"
                }
                currentSection += trimmed
            }
        } else if elementName == "section" || elementName == "body" {
            if !currentSection.isEmpty {
                sections.append(currentSection)
                currentSection = ""
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inParagraph {
            currentText += string
        }
    }
}

/// XML parser delegate for extracting text from ODT content.xml
private class ODTXMLParser: NSObject, XMLParserDelegate {
    var paragraphs: [String] = []
    private var inParagraph = false
    private var currentText = ""
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "text:p" {
            inParagraph = true
            currentText = ""
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "text:p" {
            inParagraph = false
            let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                paragraphs.append(trimmed)
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inParagraph {
            currentText += string
        }
    }
}

// MARK: - ZIPFoundation helper extensions

private extension Archive {
    /// Extract archive entry data as Data
    func extract(_ entry: Entry) throws -> Data {
        var data = Data()
        _ = try self.extract(entry) { chunk in data.append(chunk) }
        return data
    }
    
    /// Get archive entry for a specific path with error handling
    func entry(for path: String) throws -> Entry {
        guard let entry = self.entry(forPath: path) else {
            throw SupportedFormat.PlainTextError.badArchive
        }
        return entry
    }
    
    /// Find archive entry by path
    func entry(forPath path: String) -> Entry? {
        for entry in self {
            if entry.path == path {
                return entry
            }
        }
        return nil
    }
}
