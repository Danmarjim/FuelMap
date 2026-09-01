//
//  LocationSearchTests.swift
//  FuelMapTests
//
//  Created on 01/09/2026.
//

import ComposableArchitecture
import Testing

@testable import FuelMap

@MainActor
struct LocationSearchTests {
    @Test("Buscar una ciudad centra el mapa ahí, carga estaciones y quita el banner de permiso")
    func map_locationSearch_success_recentersAndLoads() async {
        let barcelona = Coordinate(latitude: 41.3874, longitude: 2.1686)
        var state = MapFeature.State()
        state.locationPermissionDenied = true
        let store = TestStore(initialState: state) {
            MapFeature()
        } withDependencies: {
            $0.apiClient = .mock()
            $0.geocodingClient.search = { _ in barcelona }
            $0.continuousClock = ImmediateClock()
        }
        store.exhaustivity = .off

        await store.send(.locationSearchSubmitted("Barcellona")) {
            $0.isSearchingLocation = true
        }
        await store.receive(\.locationSearchResponse.success) {
            $0.isSearchingLocation = false
            $0.center = barcelona
            $0.recenter = barcelona
            $0.locationPermissionDenied = false
        }
        await store.receive(\.stationsResponse.success)
    }

    @Test("Sin resultados muestra un mensaje y no toca el centro del mapa")
    func map_locationSearch_noResults_setsErrorMessage() async {
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.geocodingClient.search = { _ in throw GeocodingError.noResults }
        }
        store.exhaustivity = .off

        await store.send(.locationSearchSubmitted("Ciudad inexistente xyz"))
        await store.receive(\.locationSearchResponse.failure)

        #expect(store.state.isSearchingLocation == false)
        #expect(store.state.locationSearchError != nil)
        #expect(store.state.center == .italyDefault)
    }

    @Test(
        """
        Un fallo de red/servidor se reporta como error de conexión, no como "no hay
        resultados" — antes cualquier `catch` genérico se aplanaba a `.noResults` y el
        usuario leía que su ciudad "no existe" cuando en realidad no había conexión
        (review RELEASE-001 F1-F2, A-6).
        """
    )
    func map_locationSearch_networkFailure_reportsConnectionError() async {
        struct DummyNetworkError: Error {}
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.geocodingClient.search = { _ in throw DummyNetworkError() }
        }
        store.exhaustivity = .off

        await store.send(.locationSearchSubmitted("Milano"))
        await store.receive(\.locationSearchResponse.failure) {
            $0.locationSearchError = GeocodingError.network.userMessage
        }
    }

    @Test("Una búsqueda en blanco no dispara ninguna llamada")
    func map_locationSearch_blankQuery_isNoOp() async {
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.geocodingClient.search = unimplemented("GeocodingClient.search")
        }

        await store.send(.locationSearchSubmitted("   "))
    }

    @Test("Abrir la búsqueda limpia cualquier error de un intento anterior")
    func map_locationSearchButtonTapped_opensSheetAndClearsStaleError() async {
        var state = MapFeature.State()
        state.locationSearchError = "Nessun risultato per questa ricerca."
        let store = TestStore(initialState: state) {
            MapFeature()
        }

        await store.send(.locationSearchButtonTapped) {
            $0.isShowingLocationSearch = true
            $0.locationSearchError = nil
        }
    }

    @Test("Cerrar la hoja (swipe) limpia el error y no deja la presentación colgada")
    func map_locationSearchDismissed_closesSheetAndClearsError() async {
        var state = MapFeature.State()
        state.isShowingLocationSearch = true
        state.locationSearchError = "Nessun risultato per questa ricerca."
        let store = TestStore(initialState: state) {
            MapFeature()
        }

        await store.send(.locationSearchDismissed) {
            $0.isShowingLocationSearch = false
            $0.locationSearchError = nil
        }
    }

    @Test("Una búsqueda con éxito cierra la hoja sola (M-1: el reducer es dueño de la presentación)")
    func map_locationSearch_success_closesSheet() async {
        let barcelona = Coordinate(latitude: 41.3874, longitude: 2.1686)
        var state = MapFeature.State()
        state.isShowingLocationSearch = true
        let store = TestStore(initialState: state) {
            MapFeature()
        } withDependencies: {
            $0.apiClient = .mock()
            $0.geocodingClient.search = { _ in barcelona }
            $0.continuousClock = ImmediateClock()
        }
        store.exhaustivity = .off

        await store.send(.locationSearchSubmitted("Barcellona"))
        await store.receive(\.locationSearchResponse.success) {
            $0.isShowingLocationSearch = false
        }
    }
}
