//
//  JSONDecoder+FuelMap.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import Foundation

extension JSONDecoder {
    /// Decoder compartido para las respuestas de Supabase: snake_case → camelCase
    /// y fechas ISO8601 tolerantes a fracciones de segundo. Lo usan el `APIClient`
    /// (FM-5) y los tests del mapper.
    static let fuelMap: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let date = ISO8601.date(from: raw) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Fecha ISO8601 no reconocida: \(raw)"
                )
            }
            return date
        }
        return decoder
    }()
}
