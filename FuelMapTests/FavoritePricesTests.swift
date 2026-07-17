//
//  FavoritePricesTests.swift
//  FuelMapTests
//
//  Created on 17/07/2026.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import FuelMap

/// Precios en vivo de los favoritos (FAV-PRICE): carga, orden por precio,
/// marca del más barato y refresco al cambiar el combustible.
@MainActor
struct FavoritePricesTests {

    @Test("loadFavorites puebla la lista y trae sus precios en vivo")
    func favorites_load_populatesAndFetchesPrices() async {
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.apiClient = .mock()
            $0.favoritesClient.all = {
                [FavoriteStationInfo(id: 1, name: "Eni Roma Centro", coordinate: .italyDefault)]
            }
        }
        store.exhaustivity = .off

        await store.send(.loadFavorites)
        await store.receive(\.favoritesResponse)
        await store.receive(\.favoritePricesResponse.success)

        #expect(store.state.favorites.map(\.id) == [1])
        #expect(store.state.favoriteStations.map(\.id) == [1])
        #expect(store.state.isLoadingFavoritePrices == false)
    }

    @Test("Sin favoritos no se piden precios (no toca la API)")
    func favorites_empty_doesNotFetchPrices() async {
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.favoritesClient.all = { [] }
            // apiClient.stationsByIDs queda unimplemented: si se llamara, el test fallaría.
        }
        store.exhaustivity = .off

        await store.send(.loadFavorites)
        await store.receive(\.favoritesResponse)

        #expect(store.state.favorites.isEmpty)
        #expect(store.state.favoriteStations.isEmpty)
        #expect(store.state.isLoadingFavoritePrices == false)
    }

    @Test("favoriteDisplays ordena por precio asc y marca el más barato; sin precio va al final")
    func favorites_displays_orderByPriceAndFlagCheapest() async {
        // Favoritos: Eni (1, benzina 1.879), Tamoil (4, benzina 1.849 = más barata),
        // Esso (5, benzina 1.889) y un id inexistente (999, sin precio → "non disp.").
        let favorites = [
            FavoriteStationInfo(id: 1, name: "Eni Roma Centro", coordinate: .italyDefault),
            FavoriteStationInfo(id: 4, name: "Tamoil Ostiense", coordinate: .italyDefault),
            FavoriteStationInfo(id: 5, name: "Esso Prenestina", coordinate: .italyDefault),
            FavoriteStationInfo(id: 999, name: "Sconosciuto", coordinate: .italyDefault)
        ]
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.apiClient = .mock()
            $0.favoritesClient.all = { favorites }
        }
        store.exhaustivity = .off

        await store.send(.loadFavorites)
        await store.receive(\.favoritesResponse)
        await store.receive(\.favoritePricesResponse.success)

        // Orden por precio: Tamoil (1.849) < Eni (1.879) < Esso (1.889) < sin precio (999).
        #expect(store.state.favoriteDisplays.map(\.id) == [4, 1, 5, 999])
        #expect(store.state.cheapestFavoriteID == 4)
        // El favorito sin ese combustible no trae station (→ "non disp." en la vista).
        #expect(store.state.favoriteDisplays.last?.station == nil)
    }

    /// Estación mínima con un único precio de benzina, a `kilometers` al norte del usuario.
    private func station(id: Int, price: Decimal, kmAway kilometers: Double) -> Station {
        Station(
            id: id, name: "Stazione \(id)", brand: nil, address: nil,
            municipality: nil, province: nil,
            coordinate: Coordinate(latitude: 41.9028 + kilometers / 111.0, longitude: 12.4964),
            prices: [FuelPrice(fuel: .benzina, fuelRaw: "Benzina", price: price,
                               isSelf: true, communicatedAt: nil)]
        )
    }

    @Test("A igualdad de precio gana la más cercana, no la añadida antes")
    func favorites_priceTie_breaksByDistance() {
        // Las fixtures no tienen dos precios iguales: el empate se construye aquí.
        // El favorito 1 se añadió primero pero está a 10 km; el 2 empata a precio a 1 km.
        let far = station(id: 1, price: 1.899, kmAway: 10)
        let near = station(id: 2, price: 1.899, kmAway: 1)
        let cheaperFarther = station(id: 3, price: 1.799, kmAway: 20)
        let state = MapFeature.State(
            userLocation: Coordinate(latitude: 41.9028, longitude: 12.4964),
            favorites: [far, near, cheaperFarther].map {
                FavoriteStationInfo(id: $0.id, name: $0.name, coordinate: $0.coordinate)
            },
            favoriteStations: [far, near, cheaperFarther]
        )

        // El precio manda sobre la distancia (3 va primero pese a ser la más lejana);
        // solo dentro del empate 1.899 decide la cercanía (2 antes que 1).
        #expect(state.favoriteDisplays.map(\.id) == [3, 2, 1])
    }

    @Test("Cambiar el combustible refresca también los precios de favoritos")
    func favorites_filterChange_refetchesPrices() async {
        let favorites = [FavoriteStationInfo(id: 5, name: "Esso Prenestina", coordinate: .italyDefault)]
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.apiClient = .mock()
            $0.favoritesClient.all = { favorites }
            $0.continuousClock = ImmediateClock()
        }
        store.exhaustivity = .off

        // Carga inicial de favoritos (benzina).
        await store.send(.loadFavorites)
        await store.receive(\.favoritesResponse)
        await store.receive(\.favoritePricesResponse.success)
        #expect(store.state.favoriteDisplays.first?.price != nil)   // Esso vende benzina

        // Cambiar a GPL: Esso no lo vende → el refetch deja el favorito sin precio.
        // (En modo no-exhaustivo, `receive` salta el stationsResponse del mapa.)
        await store.send(.filters(.binding(.set(\.fuel, .gpl))))
        await store.receive(\.favoritePricesResponse.success)

        #expect(store.state.filters.fuel == .gpl)
        #expect(store.state.favoriteDisplays.first?.station == nil) // Esso sin GPL → "non disp."
    }
}
