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
}
