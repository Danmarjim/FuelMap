//
//  Station.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

/// Gasolinera (impianto) con sus precios. Modelo de dominio (RFC §2.2).
struct Station: Identifiable, Equatable, Sendable {
    let id: Int
    let name: String
    let brand: String?
    let address: String?
    let municipality: String?
    let province: String?
    let coordinate: Coordinate
    let prices: [FuelPrice]

    /// Precio más bajo entre los disponibles (self/servito y, en detalle, todos
    /// los combustibles). `nil` si no hay precios.
    var cheapest: FuelPrice? {
        prices.min { $0.price < $1.price }
    }
}
