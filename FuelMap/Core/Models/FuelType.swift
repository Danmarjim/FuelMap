//
//  FuelType.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

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

    /// Tipos que el usuario puede seleccionar en el filtro (excluye `hvo`/`altro`).
    static let selectable: [FuelType] = [.benzina, .gasolio, .gpl, .metano]

    /// Nombre para mostrar en UI.
    var label: String {
        switch self {
        case .benzina: return "Benzina"
        case .gasolio: return "Gasolio"
        case .gpl: return "GPL"
        case .metano: return "Metano"
        case .hvo: return "HVO"
        case .altro: return "Altro"
        }
    }
}
