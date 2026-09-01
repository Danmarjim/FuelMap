//
//  MapTypes.swift
//  FuelMap
//
//  Created on 01/09/2026.
//

import Foundation

/// Tipos auxiliares de `MapFeature`, extraídos por `file_length` (límite 400).

/// Valores por defecto del mapa.
enum MapDefaults {
    /// Apertura inicial (latitudeDelta) ≈ 5 km de alto: vista local centrada en el
    /// usuario, menos pines a la vista que el zoom anterior (~2 km).
    static let span: Double = 0.02
}

/// Tipo de mapa para el control de capas (RESTYLE-001 R2).
enum MapStyleOption: String, CaseIterable, Sendable, Equatable {
    case standard
    case hybrid
    case imagery

    var label: String {
        switch self {
        case .standard: return String(localized: "Standard", comment: "Tipo de mapa: estándar")
        case .hybrid: return String(localized: "Ibrida", comment: "Tipo de mapa: híbrido")
        case .imagery: return String(localized: "Satellite", comment: "Tipo de mapa: satélite")
        }
    }

    var symbol: String {
        switch self {
        case .standard: return "map"
        case .hybrid: return "map.fill"
        case .imagery: return "globe.americas.fill"
        }
    }
}

/// Criterio de orden de la lista de estaciones (RFC §4 FM-10).
enum StationSort: String, CaseIterable, Sendable, Equatable {
    case price
    case distance

    var label: String {
        switch self {
        case .price: return String(localized: "Prezzo")
        case .distance: return String(localized: "Distanza")
        }
    }
}
