//
//  APIClientTests.swift
//  FuelMapTests
//
//  Created on 04/06/2026.
//

import Testing

@testable import FuelMap

struct APIClientTests {

    private let center = Coordinate(latitude: 41.9, longitude: 12.5)

    @Test("nearbyStations devuelve estaciones del combustible pedido ordenadas por precio asc")
    func mock_nearby_sortsByPriceAscending() async throws {
        let client = APIClient.mock()
        let stations = try await client.nearbyStations(center, 5, .benzina, false)

        #expect(stations.count == StationFixtures.all.count)
        // La más barata en benzina self es Tamoil Ostiense (id 4, 1.849).
        #expect(stations.first?.id == 4)

        let cheapest = stations.compactMap { $0.cheapest?.price }
        #expect(cheapest == cheapest.sorted())
    }

    @Test("selfOnly excluye los precios servito")
    func mock_nearby_selfOnly_excludesServito() async throws {
        let client = APIClient.mock()
        let stations = try await client.nearbyStations(center, 5, .benzina, true)

        for station in stations {
            #expect(station.prices.allSatisfy { $0.isSelf && $0.fuel == .benzina })
            #expect(station.prices.count == 1)
        }
    }

    @Test("nearbyStations filtra por combustible (solo gasolio)")
    func mock_nearby_filtersByFuel() async throws {
        let client = APIClient.mock()
        let stations = try await client.nearbyStations(center, 5, .gasolio, false)

        #expect(!stations.isEmpty)
        for station in stations {
            #expect(station.prices.allSatisfy { $0.fuel == .gasolio })
        }
    }

    @Test("stationDetail devuelve la estación completa con todos los combustibles")
    func mock_stationDetail_returnsFullStation() async throws {
        let client = APIClient.mock()
        let station = try await client.stationDetail(2)

        #expect(station.id == 2)
        #expect(station.name == "Q8 Termini")
        #expect(Set(station.prices.map(\.fuel)) == [.benzina, .gasolio])
        #expect(station.prices.count == 4)
    }

    @Test("stationDetail con id desconocido lanza noResults")
    func mock_stationDetail_unknownId_throwsNoResults() async {
        let client = APIClient.mock()
        await #expect(throws: APIError.noResults) {
            _ = try await client.stationDetail(999)
        }
    }
}
