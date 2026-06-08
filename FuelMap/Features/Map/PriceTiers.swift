//
//  PriceTiers.swift
//  FuelMap
//
//  Created on 05/06/2026.
//

import Foundation
import SwiftUI

/// Nivel de precio relativo al conjunto cargado (FM-18, "heat map").
///
/// El tier es **a prueba de daltonismo**: nunca depende solo del color. Expone
/// además una `shape` (▲ ● ▼) y una `label` localizada (BASSO/MEDIO/ALTO) que
/// viajan con el color en pin, filas y detalle (design system, ver `.claude/design/`).
enum PriceTier: Equatable {
    case low   // tercio más barato
    case mid
    case high  // tercio más caro

    /// Relleno del tier (cápsula de pin, fondo de cluster). Igual en claro y oscuro.
    var fill: Color {
        switch self {
        case .low: return Color(.priceCheap)
        case .mid: return Color(.priceMid)
        case .high: return Color(.priceHigh)
        }
    }

    /// Tinta del tier para texto/icono sobre superficie de la app (brilla en oscuro).
    var ink: Color {
        switch self {
        case .low: return Color(.priceCheapInk)
        case .mid: return Color(.priceMidInk)
        case .high: return Color(.priceHighInk)
        }
    }

    /// Fondo tintado sutil para `tier-tag` y filas activas.
    var surface: Color {
        switch self {
        case .low: return Color(.priceCheapSurface)
        case .mid: return Color(.priceMidSurface)
        case .high: return Color(.priceHighSurface)
        }
    }

    /// Forma redundante daltónico-segura: ▲ bajo · ● medio · ▼ alto. SF Symbol.
    var symbolName: String {
        switch self {
        case .low: return "arrowtriangle.up.fill"
        case .mid: return "circle.fill"
        case .high: return "arrowtriangle.down.fill"
        }
    }

    /// Etiqueta localizada del nivel (it: BASSO/MEDIO/ALTO). Caso propio; la vista
    /// decide mayúsculas. Útil también para VoiceOver.
    var label: String {
        switch self {
        case .low: return String(localized: "Basso", comment: "Nivel de precio: barato")
        case .mid: return String(localized: "Medio", comment: "Nivel de precio: medio")
        case .high: return String(localized: "Alto", comment: "Nivel de precio: caro")
        }
    }

    /// Alias de compatibilidad (relleno). Los componentes migran a `fill` en R2.
    var color: Color { fill }
}

/// Umbrales por terciles de los precios del set. Si hay <3 precios o el rango es
/// degenerado (todos iguales), no clasifica (todo `.mid`).
struct PriceTiers: Equatable {
    private let lower: Decimal?
    private let upper: Decimal?

    init(prices: [Decimal]) {
        let sorted = prices.sorted()
        guard sorted.count >= 3 else {
            lower = nil
            upper = nil
            return
        }
        let lowerBound = sorted[sorted.count / 3]
        let upperBound = sorted[2 * sorted.count / 3]
        if lowerBound == upperBound {
            lower = nil
            upper = nil
        } else {
            lower = lowerBound
            upper = upperBound
        }
    }

    func tier(for price: Decimal?) -> PriceTier {
        guard let price, let lower, let upper else { return .mid }
        if price < lower { return .low }
        if price >= upper { return .high }
        return .mid
    }
}
