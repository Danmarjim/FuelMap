//
//  APIClient+Live.swift
//  FuelMap
//
//  Created on 05/06/2026.
//

import Foundation
import Supabase

extension APIClient {
    /// Implementación real sobre Supabase (RPC `nearby_stations` / `station_detail`).
    /// Reusa `NearbyStationRowDTO` + `StationMapper` (RFC §3.1, §3.2).
    static func live(client: SupabaseClient = SupabaseConfig.client) -> APIClient {
        APIClient(
            nearbyStations: { center, radiusKm, fuel, selfOnly in
                let params = NearbyParams(
                    lat: center.latitude,
                    lng: center.longitude,
                    radiusKm: radiusKm,
                    fuel: fuel.rawValue,
                    selfOnly: selfOnly
                )
                do {
                    let response = try await client.rpc("nearby_stations", params: params).execute()
                    let rows = try JSONDecoder.fuelMap.decode([NearbyStationRowDTO].self, from: response.data)
                    return StationMapper.stations(from: rows)
                } catch {
                    throw mapError(error)
                }
            },
            stationDetail: { id in
                do {
                    let response = try await client.rpc("station_detail", params: DetailParams(id: id)).execute()
                    let rows = try JSONDecoder.fuelMap.decode([NearbyStationRowDTO].self, from: response.data)
                    guard let station = StationMapper.stations(from: rows).first else {
                        throw APIError.noResults
                    }
                    return station
                } catch let error as APIError {
                    throw error
                } catch {
                    throw mapError(error)
                }
            }
        )
    }

    private static func mapError(_ error: Error) -> APIError {
        if error is DecodingError { return .decoding }
        if let urlError = error as? URLError { return .network(urlError.localizedDescription) }
        return .network(error.localizedDescription)
    }
}

// Parámetros de las RPC. `CodingKeys` mapea a los nombres de argumento SQL `in_*`.
private struct NearbyParams: Encodable {
    let lat: Double
    let lng: Double
    let radiusKm: Double
    let fuel: String
    let selfOnly: Bool

    enum CodingKeys: String, CodingKey {
        case lat = "in_lat"
        case lng = "in_lng"
        case radiusKm = "in_radius_km"
        case fuel = "in_fuel"
        case selfOnly = "in_self_only"
    }
}

private struct DetailParams: Encodable {
    let id: Int

    enum CodingKeys: String, CodingKey {
        case id = "in_id"
    }
}
