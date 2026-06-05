//
//  FuelPrice.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import Foundation

/// Precio de un combustible en una estación, distinguiendo self-service de servito.
struct FuelPrice: Equatable, Sendable {
    let fuel: FuelType
    /// Nombre original del producto en el MIMIT (p. ej. "Benzina Plus 98").
    let fuelRaw: String
    /// Precio en euros, con 3 decimales (formato MIMIT).
    let price: Decimal
    /// `true` = self-service, `false` = servito.
    let isSelf: Bool
    /// Momento en que el gestor comunicó el precio (`dtComu` del MIMIT).
    let communicatedAt: Date?
}
