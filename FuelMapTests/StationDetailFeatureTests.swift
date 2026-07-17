//
//  StationDetailFeatureTests.swift
//  FuelMapTests
//
//  Created on 04/06/2026.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import FuelMap

@MainActor
struct StationDetailFeatureTests {

    @Test("onAppear carga el detalle completo con todos los combustibles")
    func detail_onAppear_loadsFullStation() async {
        let pinStation = StationFixtures.all[0]
        let store = TestStore(
            initialState: StationDetailFeature.State(stationId: pinStation.id, station: pinStation)
        ) {
            StationDetailFeature()
        } withDependencies: {
            $0.apiClient = .mock()
            $0.purchaseClient.isPremium = { false }
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.stationResponse.success)

        #expect(store.state.isLoading == false)
        #expect(store.state.station?.id == pinStation.id)
        // El detalle completo incluye benzina y gasolio (y GPL en la fixture 1).
        let fuels = Set(store.state.station?.prices.map(\.fuel) ?? [])
        #expect(fuels.contains(.benzina))
        #expect(fuels.contains(.gasolio))
    }

    @Test("Fallo de carga sin datos previos muestra error")
    func detail_loadFailure_showsErrorWhenNoData() async {
        let store = TestStore(
            initialState: StationDetailFeature.State(stationId: 999, station: nil)
        ) {
            StationDetailFeature()
        } withDependencies: {
            $0.apiClient.stationDetail = { _ in throw APIError.noResults }
            $0.purchaseClient.isPremium = { false }
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.stationResponse.failure)

        #expect(store.state.errorMessage != nil)
    }

    @Test("favoriteToggled marca y desmarca el favorito")
    func detail_favoriteToggle() async {
        let station = StationFixtures.all[0]
        let store = TestStore(
            initialState: StationDetailFeature.State(stationId: station.id, station: station)
        ) {
            StationDetailFeature()
        } withDependencies: {
            $0.favoritesClient = .inMemory()
        }
        store.exhaustivity = .off

        await store.send(.favoriteToggled)
        await store.receive(\.favoriteStatus) { $0.isFavorite = true }

        await store.send(.favoriteToggled)
        await store.receive(\.favoriteStatus) { $0.isFavorite = false }
    }

    @Test("navigate(.googleMaps) abre Google Maps con el destino correcto")
    func detail_navigate_opensChosenApp() async {
        let station = StationFixtures.all[0]
        let opened = LockIsolated<URL?>(nil)
        let store = TestStore(
            initialState: StationDetailFeature.State(stationId: station.id, station: station)
        ) {
            StationDetailFeature()
        } withDependencies: {
            $0.openURL = OpenURLEffect { url in
                opened.setValue(url)
                return true
            }
        }

        await store.send(.navigate(.googleMaps))

        let url = opened.value?.absoluteString
        let coordinate = station.coordinate
        #expect(url?.hasPrefix("comgooglemaps://") == true)
        #expect(url?.contains("\(coordinate.latitude),\(coordinate.longitude)") == true)
    }
}
