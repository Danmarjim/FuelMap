//
//  NearbyStationRowDTO.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import Foundation

/// Fila devuelta por la RPC `nearby_stations` (RFC §3.1).
///
/// La RPC devuelve filas planas: una por (estación × combustible × self/servito).
/// `StationMapper` las agrupa por `id`. DTO de respuesta → **`Decodable`** (nunca
/// `Codable`); las claves snake_case se mapean con `.convertFromSnakeCase`.
struct NearbyStationRowDTO: Decodable, Equatable, Sendable {
    let id: Int
    let name: String?
    let brand: String?
    let address: String?
    let municipality: String?
    let province: String?
    let latitude: Double?
    let longitude: Double?
    let fuel: String
    let price: Decimal
    let isSelf: Bool
    let communicatedAt: Date?
    let distanceM: Double?
}
