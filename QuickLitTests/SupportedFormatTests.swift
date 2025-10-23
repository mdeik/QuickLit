//
//  SupportedFormatTests.swift
//  QuickLitTests
//
//  Created by Matthew Deik on 8/19/25.
//

import Testing
import Foundation
@testable import QuickLit

@Suite("SupportedFormat Tests")
struct SupportedFormatTests {
    
    // Use a computed property for temp directory that cleans up after each test
    private var tempDirectory: URL {
        let dir = TestHelpers.createTempDirectory()
        // We'll rely on the test system to clean up, or use a different approach
        return dir
    }
    
    @Test("Supported format detection from file extension")
    func testFormatDetection() {
        let tempDir = TestHelpers.createTempDirectory()
        defer { TestHelpers.cleanupTempDirectory(tempDir) }
        
        // Test each supported format
        let testCases: [(String, SupportedFormat)] = [
            ("txt", .plainText),
            ("rtf", .rtf),
            ("docx", .docX),
            ("epub", .epub),
            ("pdf", .pdf),
            ("html", .html),
            ("htm", .html),
            ("fb2", .fb2),
            ("odt", .odt)
        ]
        
        for (fileExtension, expectedFormat) in testCases {
            let url = URL(fileURLWithPath: "test.\(fileExtension)")
            let format = SupportedFormat(url: url)
            #expect(format == expectedFormat,
                   "Expected \(expectedFormat) for .\(fileExtension), got \(String(describing: format))")
        }
    }
    
    @Test("Unsupported format returns nil")
    func testUnsupportedFormat() {
        let tempDir = TestHelpers.createTempDirectory()
        defer { TestHelpers.cleanupTempDirectory(tempDir) }
        
        let unsupportedExtensions = ["doc", "xlsx", "png", "jpg", "zip", "exe"]
        
        for fileExtension in unsupportedExtensions {
            let url = URL(fileURLWithPath: "test.\(fileExtension)")
            let format = SupportedFormat(url: url)
            #expect(format == nil, "Expected nil for unsupported extension .\(fileExtension)")
        }
    }
    
    @Test("Supported extensions list contains all expected extensions")
    func testSupportedExtensions() {
        let expectedExtensions = ["txt", "rtf", "docx", "epub", "pdf", "html", "htm", "fb2", "odt"]
        let supportedExtensions = SupportedFormat.supportedExtensions
        
        #expect(Set(supportedExtensions) == Set(expectedExtensions),
               "Supported extensions don't match expected")
    }
    
    @Test("Allowed UT types match supported formats")
    func testAllowedUTTypes() {
        let allowedTypes = SupportedFormat.allowedUTTypes
        #expect(!allowedTypes.isEmpty, "Allowed UT types should not be empty")
        
        // Should have at least one type for each supported format
        #expect(allowedTypes.count >= SupportedFormat.supportedFileInfo.count,
               "Should have UT types for all supported formats")
    }
    
    @Test("Plain text extraction from TXT file")
    func testPlainTextExtraction() throws {
        let tempDir = TestHelpers.createTempDirectory()
        defer { TestHelpers.cleanupTempDirectory(tempDir) }
        
        let testContent = TestHelpers.sampleTextContent
        let fileURL = TestHelpers.createTestFile(content: testContent, fileExtension: "txt", in: tempDir)
        
        let format = SupportedFormat.plainText
        let extractedText = try format.plainText(from: fileURL)
        
        #expect(!extractedText.isEmpty, "Extracted text should not be empty")
        #expect(extractedText == testContent, "Extracted text should match original content")
    }
    
    @Test("Plain text extraction handles empty file")
    func testPlainTextEmptyFile() throws {
        let tempDir = TestHelpers.createTempDirectory()
        defer { TestHelpers.cleanupTempDirectory(tempDir) }
        
        let fileURL = TestHelpers.createTestFile(content: "", fileExtension: "txt", in: tempDir)
        
        let format = SupportedFormat.plainText
        let extractedText = try format.plainText(from: fileURL)
        
        #expect(extractedText.isEmpty, "Extracted text should be empty for empty file")
    }
    
    @Test("Plain text extraction handles file with only whitespace")
    func testPlainTextWhitespaceFile() throws {
        let tempDir = TestHelpers.createTempDirectory()
        defer { TestHelpers.cleanupTempDirectory(tempDir) }
        
        let fileURL = TestHelpers.createTestFile(content: "   \n\n\t  \n", fileExtension: "txt", in: tempDir)
        
        let format = SupportedFormat.plainText
        let extractedText = try format.plainText(from: fileURL)
        
        #expect(extractedText == "   \n\n\t  \n", "Should preserve whitespace exactly")
    }
    
    @Test("Supported format display strings are properly formatted")
    func testSupportedFormatDisplay() {
        let displayString = SupportedFormat.supportedExtensionsDisplay
        #expect(!displayString.isEmpty, "Display string should not be empty")
        
        // Should contain some of our known extensions in uppercase
        #expect(displayString.contains("TXT") || displayString.contains("PDF") || displayString.contains("EPUB"),
               "Display string should contain known extensions")
    }
    
    @Test("Supported format display lines split content appropriately")
    func testSupportedFormatDisplayLines() {
        let displayLines = SupportedFormat.supportedExtensionsDisplayLines
        #expect(!displayLines.isEmpty, "Should have at least one display line")
        #expect(displayLines.count <= 2, "Should have at most two display lines for current format count")
        
        // All lines should be non-empty
        for line in displayLines {
            #expect(!line.isEmpty, "Display line should not be empty")
        }
    }
    
    // MARK: - HTML Parsing Tests
    
    @Test("HTML extraction removes script and style tags")
    func testHTMLExtractionRemovesScriptAndStyle() throws {
        let tempDir = TestHelpers.createTempDirectory()
        defer { TestHelpers.cleanupTempDirectory(tempDir) }
        
        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Test Page</title>
            <script>alert('Hello');</script>
            <style>body { color: red; }</style>
        </head>
        <body>
            <h1>Main Heading</h1>
            <p>This is a paragraph with <strong>bold</strong> text.</p>
            <nav>Navigation should be removed</nav>
            <header>Header should be removed</header>
            <footer>Footer should be removed</footer>
        </body>
        </html>
        """
        
        let fileURL = TestHelpers.createTestFile(content: htmlContent, fileExtension: "html", in: tempDir)
        let format = SupportedFormat.html
        let extractedText = try format.plainText(from: fileURL)
        
        #expect(!extractedText.isEmpty, "Extracted HTML text should not be empty")
        #expect(extractedText.contains("Main Heading"), "Should extract heading text")
        #expect(extractedText.contains("This is a paragraph with bold text"), "Should extract paragraph text")
        #expect(!extractedText.contains("alert"), "Should remove script content")
        #expect(!extractedText.contains("color: red"), "Should remove style content")
        #expect(!extractedText.contains("Navigation should be removed"), "Should remove nav elements")
        #expect(!extractedText.contains("Header should be removed"), "Should remove header elements")
        #expect(!extractedText.contains("Footer should be removed"), "Should remove footer elements")
    }
    
    @Test("HTML extraction handles malformed HTML gracefully")
    func testHTMLExtractionMalformedHTML() throws {
        let tempDir = TestHelpers.createTempDirectory()
        defer { TestHelpers.cleanupTempDirectory(tempDir) }
        
        let malformedHTML = """
        <html>
        <body>
            <p>This is some text
            <div>More text without closing tag
        </body>
        </html>
        """
        
        let fileURL = TestHelpers.createTestFile(content: malformedHTML, fileExtension: "html", in: tempDir)
        let format = SupportedFormat.html
        let extractedText = try format.plainText(from: fileURL)
        
        #expect(!extractedText.isEmpty, "Should handle malformed HTML gracefully")
        #expect(extractedText.contains("This is some text"), "Should extract text from malformed HTML")
    }
    
    @Test("HTML extraction preserves text structure")
    func testHTMLExtractionPreservesStructure() throws {
        let tempDir = TestHelpers.createTempDirectory()
        defer { TestHelpers.cleanupTempDirectory(tempDir) }
        
        let structuredHTML = """
        <html>
        <body>
            <h1>Chapter 1</h1>
            <p>First paragraph.</p>
            <p>Second paragraph with <em>emphasis</em>.</p>
            <h2>Subsection</h2>
            <p>Third paragraph.</p>
        </body>
        </html>
        """
        
        let fileURL = TestHelpers.createTestFile(content: structuredHTML, fileExtension: "html", in: tempDir)
        let format = SupportedFormat.html
        let extractedText = try format.plainText(from: fileURL)
        
        #expect(extractedText.contains("Chapter 1"), "Should extract chapter title")
        #expect(extractedText.contains("First paragraph"), "Should extract first paragraph")
        #expect(extractedText.contains("Second paragraph with emphasis"), "Should extract second paragraph with inline formatting")
        #expect(extractedText.contains("Subsection"), "Should extract subsection title")
        #expect(extractedText.contains("Third paragraph"), "Should extract third paragraph")
    }
    
    // MARK: - PDF Parsing Tests
    
    @Test("PDF extraction handles non-PDF files gracefully")
    func testPDFExtractionNonPDFFile() throws {
        let tempDir = TestHelpers.createTempDirectory()
        defer { TestHelpers.cleanupTempDirectory(tempDir) }
        
        // Create a text file but name it as PDF to test error handling
        let fileURL = TestHelpers.createTestFile(content: "This is not a PDF", fileExtension: "pdf", in: tempDir)
        let format = SupportedFormat.pdf
        
        #expect(throws: SupportedFormat.PlainTextError.self) {
            try format.plainText(from: fileURL)
        }
    }
    
    // MARK: - RTF Parsing Tests
    
    @Test("RTF extraction handles basic formatting")
    func testRTFExtraction() throws {
        let tempDir = TestHelpers.createTempDirectory()
        defer { TestHelpers.cleanupTempDirectory(tempDir) }
        
        // Simple RTF content with basic formatting
        let rtfContent = """
        {\\rtf1\\ansi\\deff0
        {\\fonttbl {\\f0 Times New Roman;}}
        \\f0\\fs24 This is a test document with \\b bold\\b0  and \\i italic\\i0  text.
        \\par
        Another paragraph with different content.
        }
        """
        
        let fileURL = TestHelpers.createTestFile(content: rtfContent, fileExtension: "rtf", in: tempDir)
        let format = SupportedFormat.rtf
        let extractedText = try format.plainText(from: fileURL)
        
        #expect(!extractedText.isEmpty, "Extracted RTF text should not be empty")
        #expect(extractedText.contains("This is a test document"), "Should extract main text content")
        #expect(extractedText.contains("Another paragraph"), "Should extract paragraph content")
        // Note: Formatting (bold, italic) is removed in plain text extraction
    }
    
    @Test("RTF extraction handles malformed RTF without crashing")
    func testRTFExtractionMalformed() throws {
        let tempDir = TestHelpers.createTempDirectory()
        defer { TestHelpers.cleanupTempDirectory(tempDir) }
        
        let malformedRTF = "This is not valid RTF content"
        let fileURL = TestHelpers.createTestFile(content: malformedRTF, fileExtension: "rtf", in: tempDir)
        let format = SupportedFormat.rtf
        
        // The main goal is to ensure this doesn't crash
        // We don't care about the result for this specific test
        _ = try? format.plainText(from: fileURL)
        
        // If we get here without crashing, the test passes
        #expect(true, "Should not crash when processing malformed RTF")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Plain text error types have proper descriptions")
    func testPlainTextErrorDescriptions() {
        let unsupportedYet = SupportedFormat.PlainTextError.unsupportedYet
        let badArchive = SupportedFormat.PlainTextError.badArchive
        let unsupportedFormat = SupportedFormat.PlainTextError.unsupportedFormat
        
        #expect(unsupportedYet.errorDescription != nil)
        #expect(badArchive.errorDescription != nil)
        #expect(unsupportedFormat.errorDescription != nil)
        
        #expect(unsupportedYet.errorDescription?.contains("coming soon") == true)
        #expect(badArchive.errorDescription?.contains("could not be opened") == true)
        #expect(unsupportedFormat.errorDescription?.contains("not supported") == true)
    }
    
    @Test("File format with mixed case extensions")
    func testMixedCaseExtensions() {
        let mixedCaseExtensions = ["TXT", "Html", "PDF", "DocX", "EPUB"]
        
        for fileExtension in mixedCaseExtensions {
            let url = URL(fileURLWithPath: "test.\(fileExtension)")
            let format = SupportedFormat(url: url)
            #expect(format != nil, "Should handle mixed case extension: .\(fileExtension)")
        }
    }
    
    @Test("URL with query parameters and fragments")
    func testURLWithQueryParameters() {
        let url = URL(string: "https://example.com/document.txt?param=value#fragment")!
        let format = SupportedFormat(url: url)
        #expect(format == .plainText, "Should extract format from URL with query parameters")
    }
    
    @Test("File URLs with special characters")
    func testFileURLsWithSpecialCharacters() {
        let specialNames = [
            "document with spaces.txt",
            "file-with-dashes.html",
            "file_with_underscores.pdf",
            "file.multiple.dots.rtf"
        ]
        
        for fileName in specialNames {
            let url = URL(fileURLWithPath: fileName)
            let format = SupportedFormat(url: url)
            #expect(format != nil, "Should handle filename: \(fileName)")
        }
    }
    
}
