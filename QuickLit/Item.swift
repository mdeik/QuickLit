//
//  Item.swift
//  QuickLit
//
//  Created by Matthew Deik on 8/19/25.
//

import Foundation
import SwiftData

/// Legacy data model from SwiftUI template - currently unused in QuickLit
/// This was part of the default SwiftUI template and may be removed in future versions
/// The app primarily uses ReadingMaterial for its core functionality
@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
