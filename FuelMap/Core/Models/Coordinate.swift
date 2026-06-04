//
//  Coordinate.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import Foundation

/// Coordenada geográfica validada (lat/lng presentes y en rango).
struct Coordinate: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
}

extension Coordinate {
    /// Distancia en metros a otra coordenada (fórmula de haversine).
    func distance(to other: Coordinate) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let dLat = (other.latitude - latitude) * .pi / 180
        let dLon = (other.longitude - longitude) * .pi / 180
        let haversine = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return earthRadius * 2 * atan2(sqrt(haversine), sqrt(1 - haversine))
    }
}

extension Coordinate {
    /// Construye una coordenada validando que lat/lng existan, no sean (0,0)
    /// —marcador habitual de "sin datos"— y estén en rango mundial.
    ///
    /// Se valida rango mundial (no solo Italia) para no acoplar el modelo al país
    /// y permitir la expansión futura (PRD non-goal). Devuelve `nil` si no es válida
    /// (NF6: las coordenadas del MIMIT son voluntarias y pueden faltar).
    static func validated(latitude: Double?, longitude: Double?) -> Coordinate? {
        guard let latitude, let longitude else { return nil }
        guard latitude != 0 || longitude != 0 else { return nil }
        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        return Coordinate(latitude: latitude, longitude: longitude)
    }
}
