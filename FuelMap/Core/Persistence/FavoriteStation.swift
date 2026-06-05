//
//  FavoriteStation.swift
//  FuelMap
//
//  Created on 05/06/2026.
//

import Foundation
import SwiftData

/// Estación marcada como favorita, persistida localmente con SwiftData (FM-12).
@Model
final class FavoriteStation {
    @Attribute(.unique) var id: Int
    var name: String
    var latitude: Double
    var longitude: Double
    var addedAt: Date

    init(id: Int, name: String, latitude: Double, longitude: Double, addedAt: Date) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.addedAt = addedAt
    }
}
