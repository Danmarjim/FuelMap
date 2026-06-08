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
    /// Para VoiceOver y donde se quiera la unidad embebida.
    var fuelPriceLabel: String {
        "\(fuelPriceValue) €"
    }

    /// Precio solo número, 3 decimales (p. ej. "1,879"), sin símbolo. Para la UI
    /// donde la unidad (€/L) se muestra aparte (pin, fila, detalle).
    var fuelPriceValue: String {
        formatted(.number.precision(.fractionLength(3)))
    }
}
