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
    // Formatters cacheados: construirlos es caro y `ISO8601DateFormatter` es
    // thread-safe para lectura, de ahí `nonisolated(unsafe)`.
    nonisolated(unsafe) private static let withFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func date(from string: String) -> Date? {
        withFractional.date(from: string) ?? plain.date(from: string)
    }
}
