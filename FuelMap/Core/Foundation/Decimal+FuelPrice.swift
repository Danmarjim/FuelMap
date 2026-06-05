//
//  Decimal+FuelPrice.swift
//  FuelMap
//
//  Created on 05/06/2026.
//

import Foundation

extension Decimal {
    /// Precio de carburante formateado con 3 decimales y símbolo de euro
    /// (p. ej. "1,879 €"). Usa el locale del dispositivo para el separador.
    var fuelPriceLabel: String {
        "\(formatted(.number.precision(.fractionLength(3)))) €"
    }
}
