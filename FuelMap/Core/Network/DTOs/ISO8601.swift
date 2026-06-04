//
//  ISO8601.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import Foundation

/// Parseo de timestamps ISO8601 de Supabase/PostgREST, tolerante a la presencia
/// o ausencia de fracciones de segundo (los `timestamptz` pueden venir con o sin
/// microsegundos, y `.iso8601` por defecto falla con fracciones).
enum ISO8601 {
    static func date(from string: String) -> Date? {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: string) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }
}
