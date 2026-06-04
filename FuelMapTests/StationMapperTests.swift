//
//  StationMapperTests.swift
//  FuelMapTests
//
//  Created on 04/06/2026.
//

import Foundation
import Testing

@testable import FuelMap

struct StationMapperTests {

    private func decodeRows(_ json: String) throws -> [NearbyStationRowDTO] {
        try JSONDecoder.fuelMap.decode([NearbyStationRowDTO].self, from: Data(json.utf8))
    }

    @Test("Agrupa filas planas por estación, una Station por id con sus precios")
    func mapper_groupsRowsByStation() throws {
        let json = """
        [
          {
            "id": 1, "name": "Distributore A", "brand": "Agip Eni",
            "address": "Via Roma 1", "municipality": "Roma", "province": "RM",
            "latitude": 41.9, "longitude": 12.5,
            "fuel": "benzina", "price": 1.899, "is_self": true,
            "communicated_at": "2026-06-01T21:30:06+00:00", "distance_m": 120.5
          },
          {
            "id": 1, "name": "Distributore A", "brand": "Agip Eni",
            "address": "Via Roma 1", "municipality": "Roma", "province": "RM",
            "latitude": 41.9, "longitude": 12.5,
            "fuel": "benzina", "price": 1.999, "is_self": false,
            "communicated_at": "2026-06-01T21:30:06+00:00", "distance_m": 120.5
          },
          {
            "id": 2, "name": "Distributore B", "brand": "Q8",
            "address": "Via Milano 2", "municipality": "Milano", "province": "MI",
            "latitude": 45.46, "longitude": 9.19,
            "fuel": "benzina", "price": 1.949, "is_self": true,
            "communicated_at": "2026-06-01T20:00:00+00:00", "distance_m": 850.0
          }
        ]
        """
        let stations = StationMapper.stations(from: try decodeRows(json))

        #expect(stations.count == 2)
        #expect(stations.map(\.id) == [1, 2])

        let first = try #require(stations.first)
        #expect(first.name == "Distributore A")
        #expect(first.province == "RM")
        #expect(first.prices.count == 2)
        #expect(first.prices.contains { $0.isSelf && $0.price == Decimal(string: "1.899") })
        #expect(first.prices.contains { !$0.isSelf && $0.price == Decimal(string: "1.999") })
    }

    @Test("Descarta estaciones sin coordenadas válidas (nulas o 0,0)")
    func mapper_discardsInvalidCoordinates() throws {
        let json = """
        [
          {
            "id": 1, "name": "Valida", "brand": null, "address": null,
            "municipality": null, "province": null,
            "latitude": 41.9, "longitude": 12.5,
            "fuel": "gasolio", "price": 1.799, "is_self": true,
            "communicated_at": null, "distance_m": null
          },
          {
            "id": 2, "name": "Sin coords", "brand": null, "address": null,
            "municipality": null, "province": null,
            "latitude": null, "longitude": null,
            "fuel": "gasolio", "price": 1.700, "is_self": true,
            "communicated_at": null, "distance_m": null
          },
          {
            "id": 3, "name": "Cero", "brand": null, "address": null,
            "municipality": null, "province": null,
            "latitude": 0, "longitude": 0,
            "fuel": "gasolio", "price": 1.650, "is_self": true,
            "communicated_at": null, "distance_m": null
          }
        ]
        """
        let stations = StationMapper.stations(from: try decodeRows(json))

        #expect(stations.map(\.id) == [1])
    }

    @Test("Combustible desconocido cae a .altro y el precio se redondea a 3 decimales")
    func mapper_normalizesFuelAndRoundsPrice() throws {
        let json = """
        [
          {
            "id": 1, "name": "X", "brand": null, "address": null,
            "municipality": null, "province": null,
            "latitude": 41.9, "longitude": 12.5,
            "fuel": "Blue Super", "price": 2.1299, "is_self": true,
            "communicated_at": null, "distance_m": null
          }
        ]
        """
        let station = try #require(StationMapper.stations(from: try decodeRows(json)).first)
        let price = try #require(station.prices.first)

        #expect(price.fuel == .altro)
        #expect(price.price == Decimal(string: "2.13"))
    }

    @Test("station.cheapest devuelve el precio mínimo")
    func station_cheapest_returnsMinPrice() throws {
        let station = Station(
            id: 1, name: "X", brand: nil, address: nil, municipality: nil, province: nil,
            coordinate: Coordinate(latitude: 41.9, longitude: 12.5),
            prices: [
                FuelPrice(
                    fuel: .benzina,
                    price: try #require(Decimal(string: "1.999")),
                    isSelf: false,
                    communicatedAt: nil
                ),
                FuelPrice(
                    fuel: .benzina,
                    price: try #require(Decimal(string: "1.899")),
                    isSelf: true,
                    communicatedAt: nil
                )
            ]
        )
        #expect(station.cheapest?.price == Decimal(string: "1.899"))
        #expect(station.cheapest?.isSelf == true)
    }

    @Test("Estación sin precios no tiene cheapest")
    func station_cheapest_emptyIsNil() {
        let station = Station(
            id: 1, name: "X", brand: nil, address: nil, municipality: nil, province: nil,
            coordinate: Coordinate(latitude: 41.9, longitude: 12.5),
            prices: []
        )
        #expect(station.cheapest == nil)
    }
}
