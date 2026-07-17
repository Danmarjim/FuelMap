//
//  APIClient+Mock.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import Foundation

extension APIClient {
    /// Mock con fixtures. `center`/`radiusKm` se ignoran (las fixtures tienen
    /// coordenadas fijas en Roma): devuelve las estaciones con el combustible pedido,
    /// con los precios filtrados a ese combustible (y a self si `selfOnly`), ordenadas
    /// por precio ascendente. Útil para desarrollo y previews hasta tener Supabase.
    static func mock(stations: [Station] = StationFixtures.all) -> APIClient {
        APIClient(
            nearbyStations: { center, _, fuel, selfOnly in
                // Traslada las fixtures (ancladas en Roma) alrededor del `center` pedido,
                // para que los pins aparezcan donde esté el mapa (también con ubicación real).
                let dLat = center.latitude - StationFixtures.anchor.latitude
                let dLng = center.longitude - StationFixtures.anchor.longitude
                return stations
                    .compactMap { station -> Station? in
                        var prices = station.prices.filter { $0.fuel == fuel }
                        if selfOnly { prices = prices.filter(\.isSelf) }
                        guard !prices.isEmpty else { return nil }
                        let moved = Coordinate(
                            latitude: station.coordinate.latitude + dLat,
                            longitude: station.coordinate.longitude + dLng
                        )
                        return station.with(prices: prices, coordinate: moved)
                    }
                    .sorted { lhs, rhs in
                        let lhsPrice = lhs.cheapest?.price ?? .greatestFiniteMagnitude
                        let rhsPrice = rhs.cheapest?.price ?? .greatestFiniteMagnitude
                        return lhsPrice < rhsPrice
                    }
            },
            stationDetail: { id in
                guard let station = stations.first(where: { $0.id == id }) else {
                    throw APIError.noResults
                }
                return station
            },
            stationsByIDs: { ids, fuel, selfOnly in
                let wanted = Set(ids)
                return stations
                    .filter { wanted.contains($0.id) }
                    .compactMap { station -> Station? in
                        var prices = station.prices.filter { $0.fuel == fuel }
                        if selfOnly { prices = prices.filter(\.isSelf) }
                        guard !prices.isEmpty else { return nil }
                        return station.with(prices: prices)
                    }
            }
        )
    }
}

private extension Station {
    func with(prices: [FuelPrice], coordinate: Coordinate? = nil) -> Station {
        Station(
            id: id, name: name, brand: brand, address: address,
            municipality: municipality, province: province,
            coordinate: coordinate ?? self.coordinate, prices: prices
        )
    }
}

// MARK: - Fixtures

/// Gasolineras de muestra (zona de Roma) para mock y previews.
/// Todas con benzina y gasolio (self/servito); algunas además con GPL o metano
/// (solo self) para que cambiar de combustible en los filtros sea visible.
enum StationFixtures {
    static let all: [Station] = [
        station(
            id: 1, name: "Eni Roma Centro", brand: "Eni", address: "Via Cavour 100",
            lat: 41.9009, lng: 12.4933,
            benzinaSelf: "1.879", benzinaServ: "1.989", gasolioSelf: "1.789", gasolioServ: "1.899",
            gplSelf: "0.729"
        ),
        station(
            id: 2, name: "Q8 Termini", brand: "Q8", address: "Via Marsala 20",
            lat: 41.9008, lng: 12.5010,
            benzinaSelf: "1.859", benzinaServ: "1.969", gasolioSelf: "1.769", gasolioServ: "1.879"
        ),
        station(
            id: 3, name: "IP Trastevere", brand: "IP", address: "Viale di Trastevere 150",
            lat: 41.8790, lng: 12.4690,
            benzinaSelf: "1.899", benzinaServ: "1.999", gasolioSelf: "1.809", gasolioServ: "1.919",
            gplSelf: "0.749"
        ),
        station(
            id: 4, name: "Tamoil Ostiense", brand: "Tamoil", address: "Via Ostiense 300",
            lat: 41.8650, lng: 12.4810,
            benzinaSelf: "1.849", benzinaServ: "1.959", gasolioSelf: "1.759", gasolioServ: "1.869",
            gplSelf: "0.719"
        ),
        station(
            id: 5, name: "Esso Prenestina", brand: "Esso", address: "Via Prenestina 450",
            lat: 41.8950, lng: 12.5400,
            benzinaSelf: "1.889", benzinaServ: "1.979", gasolioSelf: "1.799", gasolioServ: "1.909",
            metanoSelf: "1.399"
        ),
        station(
            id: 6, name: "Api Flaminio", brand: "Api", address: "Via Flaminia 80",
            lat: 41.9180, lng: 12.4760,
            benzinaSelf: "1.869", benzinaServ: "1.949", gasolioSelf: "1.779", gasolioServ: "1.889",
            metanoSelf: "1.379"
        )
    ]

    /// Ancla de las fixtures (centro de Roma). El mock traslada relativo a este punto.
    static let anchor = Coordinate.italyDefault

    private static let communicatedAt = ISO8601.date(from: "2026-06-03T08:00:00+00:00")

    private static func price(_ string: String) -> Decimal { Decimal(string: string) ?? .zero }

    // swiftlint:disable:next function_parameter_count
    private static func station(
        id: Int, name: String, brand: String, address: String,
        lat: Double, lng: Double,
        benzinaSelf: String, benzinaServ: String, gasolioSelf: String, gasolioServ: String,
        gplSelf: String? = nil, metanoSelf: String? = nil
    ) -> Station {
        var prices: [FuelPrice] = [
            FuelPrice(fuel: .benzina, fuelRaw: "Benzina", price: price(benzinaSelf),
                      isSelf: true, communicatedAt: communicatedAt),
            FuelPrice(fuel: .benzina, fuelRaw: "Benzina", price: price(benzinaServ),
                      isSelf: false, communicatedAt: communicatedAt),
            FuelPrice(fuel: .gasolio, fuelRaw: "Gasolio", price: price(gasolioSelf),
                      isSelf: true, communicatedAt: communicatedAt),
            FuelPrice(fuel: .gasolio, fuelRaw: "Gasolio", price: price(gasolioServ),
                      isSelf: false, communicatedAt: communicatedAt)
        ]
        if let gplSelf {
            prices.append(FuelPrice(fuel: .gpl, fuelRaw: "GPL", price: price(gplSelf),
                                    isSelf: true, communicatedAt: communicatedAt))
        }
        if let metanoSelf {
            prices.append(FuelPrice(fuel: .metano, fuelRaw: "Metano", price: price(metanoSelf),
                                    isSelf: true, communicatedAt: communicatedAt))
        }
        return Station(
            id: id, name: name, brand: brand, address: address,
            municipality: "Roma", province: "RM",
            coordinate: Coordinate(latitude: lat, longitude: lng),
            prices: prices
        )
    }
}
