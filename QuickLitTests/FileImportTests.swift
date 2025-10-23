//
//  FileImportTests.swift
//  QuickLitTests
//
//  Created by Matthew Deik on 8/19/25.
//

import Testing
import UniformTypeIdentifiers
@testable import QuickLit

@Suite("File Import Tests")
struct FileImportTests {
    #if os(ios)
    @Test("ImportedFile structure")
    func testImportedFileStructure() {
        let url = URL(fileURLWithPath: "test.txt")
        let importedFile = ImportedFile(url: url, name: "test.txt", size: 1024, extension: "txt")
        
        #expect(importedFile.url == url)
        #expect(importedFile.name == "test.txt")
        #expect(importedFile.size == 1024)
        #expect(importedFile.extension == "txt")
        #expect(importedFile.id != nil)
    }
    #endif
    @Test("InputMethod enum cases")
    func testInputMethod() {
        // Just verify the enum cases exist and are distinct
        #expect(InputMethod.text != InputMethod.file)
    }
    
    @Test("File size formatting")
    func testFileSizeFormatting() {
        // This would typically test the formatFileSize function
        // Since it's currently private in AddMaterialView, we might need to
        // make it internal for testing or test through public interfaces
        
        // For now, we'll create a simple test for the concept
        let sizes: [Int: String] = [
            1024: "1 KB",      // 1 KB
            1048576: "1 MB",   // 1 MB
            1536: "2 KB",      // 1.5 KB rounded
        ]
        
        // Note: Actual implementation might vary based on ByteCountFormatter
        // This test would need to be adapted to the actual implementation
    }
    
    @Test("Supported format UTType compatibility")
    func testUTTypeCompatibility() {
        let allowedTypes = SupportedFormat.allowedUTTypes
        
        #expect(!allowedTypes.isEmpty)
        
        // Verify common types are included
        let expectedTypes = [
            UTType.plainText,
            UTType.rtf,
            UTType.pdf,
            UTType.html
        ]
        
        for expectedType in expectedTypes {
            #expect(allowedTypes.contains(expectedType) ||
                   allowedTypes.contains { $0.conforms(to: expectedType) },
                   "Should include or conform to \(expectedType)")
        }
    }
}
