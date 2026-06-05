//
//  NavApp.swift
//  FuelMap
//
//  Created on 05/06/2026.
//

import Foundation

/// App de navegación a la que delegar las indicaciones (FM-17).
enum NavApp: String, CaseIterable, Equatable, Sendable {
    case appleMaps
    case googleMaps
    case waze

    var label: String {
        switch self {
        case .appleMaps: return String(localized: "Mappe")
        case .googleMaps: return "Google Maps"
        case .waze: return "Waze"
        }
    }

    /// URL para comprobar si la app está instalada (`canOpenURL`). `nil` = siempre disponible (Apple Maps).
    var probeURL: URL? {
        switch self {
        case .appleMaps: return nil
        case .googleMaps: return URL(string: "comgooglemaps://")
        case .waze: return URL(string: "waze://")
        }
    }

    /// Deep link de "cómo llegar" al destino.
    func directionsURL(to coordinate: Coordinate) -> URL? {
        let destination = "\(coordinate.latitude),\(coordinate.longitude)"
        switch self {
        case .appleMaps:
            return URL(string: "maps://?daddr=\(destination)")
        case .googleMaps:
            return URL(string: "comgooglemaps://?daddr=\(destination)&directionsmode=driving")
        case .waze:
            return URL(string: "waze://?ll=\(destination)&navigate=yes")
        }
    }
}
