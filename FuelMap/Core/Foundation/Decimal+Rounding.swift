//
//  Decimal+Rounding.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import Foundation

extension Decimal {
    /// Redondea a `scale` decimales. Se usa al mapear precios a 3 decimales para
    /// neutralizar cualquier imprecisión introducida al decodificar `Decimal` desde
    /// un número JSON (la ruta vía `Double` puede dar 1.8989999… en iOS < 18).
    func rounded(_ scale: Int, mode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
        var result = Decimal()
        var value = self
        NSDecimalRound(&result, &value, scale, mode)
        return result
    }
}
