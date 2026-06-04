//
//  Coordinate.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

/// Coordenada geográfica validada (lat/lng presentes y en rango).
struct Coordinate: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
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
