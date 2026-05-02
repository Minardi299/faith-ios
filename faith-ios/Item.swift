//
//  Item.swift
//  faith-ios
//
//  Created by Minh on 2026-05-01.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
