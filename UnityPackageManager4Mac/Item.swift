//
//  Item.swift
//  UnityPackageManager4Mac
//
//  Created by Utaha Takanashi on 2026/02/26.
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
