//
//  PriceTiers.swift
//  FuelMap
//
//  Created on 05/06/2026.
//

import Foundation
import SwiftUI

/// Nivel de precio relativo al conjunto cargado (FM-18, "heat map").
enum PriceTier: Equatable {
    case low   // tercio más barato
    case mid
    case high  // tercio más caro

    var color: Color {
        switch self {
        case .low: return .green
        case .mid: return .orange
        case .high: return .red
        }
    }
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
