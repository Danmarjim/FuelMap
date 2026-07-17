//
//  FavoritePricesTests.swift
//  FuelMapTests
//
//  Created on 17/07/2026.
//

import ComposableArchitecture
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
