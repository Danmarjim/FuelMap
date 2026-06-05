//
//  FuelType.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import Foundation

/// Tipo de combustible normalizado.
///
/// Los `rawValue` coinciden con la normalización que aplica el sync del backend
/// (ADR-003): `descCarburante` del MIMIT → uno de estos casos. `altro` es el
/// fallback para variantes no mapeadas.
enum FuelType: String, Sendable, CaseIterable, Equatable {
    case benzina
    case gasolio
    case gpl
    case metano
    case hvo
    case altro

    /// Tipos que el usuario puede seleccionar en el filtro (excluye solo `altro`).
    static let selectable: [FuelType] = [.benzina, .gasolio, .gpl, .metano, .hvo]

    /// Nombre localizado para mostrar en UI.
    var label: String {
        switch self {
        case .benzina: return String(localized: "Benzina")
        case .gasolio: return String(localized: "Gasolio")
        case .gpl: return String(localized: "GPL")
        case .metano: return String(localized: "Metano")
        case .hvo: return "HVO"
        case .altro: return String(localized: "Altro")
        }
    }
}
