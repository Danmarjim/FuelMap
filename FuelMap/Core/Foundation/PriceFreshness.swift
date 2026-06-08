//
//  PriceFreshness.swift
//  FuelMap
//
//  Created on 08/06/2026.
//

import Foundation

/// Decisión de "precio obsoleto" del MIMIT (umbral de UX, 48 h). Función pura testeable.
enum PriceFreshness {
    /// Horas a partir de las cuales un precio se considera obsoleto.
    static let staleThresholdHours: Double = 48

    static func isStale(_ date: Date, now: Date = .now) -> Bool {
        date < now.addingTimeInterval(-staleThresholdHours * 3600)
    }
}
