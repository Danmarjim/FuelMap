//
//  StationMapper.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

/// Mapea las filas planas de la RPC `nearby_stations` a modelos de dominio `Station`.
///
/// - Agrupa por `id` (la RPC devuelve una fila por combustible/self).
/// - Preserva el orden de primera aparición (la RPC ordena por precio asc).
/// - Descarta estaciones con coordenadas inválidas (NF6).
/// - Normaliza el combustible a `FuelType` (fallback `.altro`) y redondea precios a 3 decimales.
enum StationMapper {
    static func stations(from rows: [NearbyStationRowDTO]) -> [Station] {
        var order: [Int] = []
        var grouped: [Int: [NearbyStationRowDTO]] = [:]

        for row in rows {
            if grouped[row.id] == nil { order.append(row.id) }
            grouped[row.id, default: []].append(row)
        }

        return order.compactMap { id in
            guard let group = grouped[id], let first = group.first else { return nil }
            guard let coordinate = Coordinate.validated(
                latitude: first.latitude,
                longitude: first.longitude
            ) else { return nil }

            let prices = group.map { row in
                FuelPrice(
                    fuel: FuelType(rawValue: row.fuel) ?? .altro,
                    fuelRaw: row.fuelRaw?.nilIfEmpty ?? row.fuel,
                    price: row.price.rounded(3),
                    isSelf: row.isSelf,
                    communicatedAt: row.communicatedAt
                )
            }

            let name = first.name?.nilIfEmpty
                ?? first.brand?.nilIfEmpty
                ?? first.municipality?.nilIfEmpty
                ?? "Distributore"

            return Station(
                id: id,
                name: name,
                brand: first.brand?.nilIfEmpty,
                address: first.address?.nilIfEmpty,
                municipality: first.municipality?.nilIfEmpty,
                province: first.province?.nilIfEmpty,
                coordinate: coordinate,
                prices: prices
            )
        }
    }
}
