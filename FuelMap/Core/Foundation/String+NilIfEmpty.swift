//
//  String+NilIfEmpty.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

extension String {
    /// Devuelve `nil` si la cadena, tras recortar espacios, queda vacía.
    /// Útil para tratar campos del MIMIT que llegan como cadena vacía en vez de nulos.
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
