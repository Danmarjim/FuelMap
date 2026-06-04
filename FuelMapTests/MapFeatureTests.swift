//
//  MapFeatureTests.swift
//  FuelMapTests
//
//  Created on 04/06/2026.
//

import ComposableArchitecture
import CoreLocation
import Testing

@testable import FuelMap

@MainActor
struct MapFeatureTests {

    @Test("onAppear con permiso concedido centra en el usuario y carga estaciones")
    func map_onAppear_loadsStationsAtUserLocation() async {
        let userCoord = Coordinate(latitude: 45.46, longitude: 9.19)
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.apiClient = .mock()
            $0.locationClient.requestWhenInUse = { .authorizedWhenInUse }
            $0.locationClient.currentLocation = { userCoord }
            $0.continuousClock = ImmediateClock()
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.locationResponse)
        await store.receive(\.stationsResponse.success)

        #expect(store.state.center == userCoord)
        #expect(!store.state.stations.isEmpty)
        #expect(store.state.isLoading == false)
    }

    @Test("Permiso denegado: usa el centro por defecto y carga igualmente")
    func map_onAppear_deniedUsesDefaultCenter() async {
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.apiClient = .mock()
            $0.locationClient.requestWhenInUse = { .denied }
            $0.continuousClock = ImmediateClock()
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.locationResponse)
        await store.receive(\.stationsResponse.success)

        #expect(store.state.center == .italyDefault)
        #expect(!store.state.stations.isEmpty)
    }

    @Test("Mover el mapa hace debounce y cancela la carga anterior")
    func map_cameraChanged_debouncesAndCancelsPrevious() async {
        let clock = TestClock()
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.apiClient = .mock()
            $0.continuousClock = clock
        }
        store.exhaustivity = .off

        let first = Coordinate(latitude: 41.0, longitude: 12.0)
        let second = Coordinate(latitude: 45.0, longitude: 9.0)
        await store.send(.mapCameraChanged(center: first))
        await store.send(.mapCameraChanged(center: second))

        await clock.advance(by: .milliseconds(400))
        await store.receive(\.stationsResponse.success)

        #expect(store.state.center == second)
    }

    @Test("Cambios de cámara sub-significativos (jitter) no recargan")
    func map_cameraChanged_ignoresJitter() async {
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.apiClient = .mock()
            $0.continuousClock = ImmediateClock()
        }
        // Jitter dentro del epsilon (0.0005) respecto al centro por defecto (Roma):
        // no debe mutar estado ni lanzar efectos (aserción exhaustiva por defecto).
        let jitter = Coordinate(latitude: 41.9030, longitude: 12.4966)
        await store.send(.mapCameraChanged(center: jitter))
    }

    @Test("Un fallo de la API muestra mensaje de error")
    func map_stationsResponseFailure_setsError() async {
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.apiClient.nearbyStations = { _, _, _, _ in throw APIError.noResults }
            $0.continuousClock = ImmediateClock()
        }
        store.exhaustivity = .off

        await store.send(.reload)
        await store.receive(\.stationsResponse.failure)

        #expect(store.state.errorMessage != nil)
        #expect(store.state.isLoading == false)
    }

    @Test("Cambiar un filtro recarga las estaciones")
    func map_filterChange_reloads() async {
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.apiClient = .mock()
            $0.continuousClock = ImmediateClock()
        }
        store.exhaustivity = .off

        await store.send(.filters(.binding(.set(\.fuel, .gasolio))))
        await store.receive(\.stationsResponse.success)

        #expect(store.state.filters.fuel == .gasolio)
        #expect(!store.state.stations.isEmpty)
    }

    @Test("La respuesta marca la estación más barata")
    func map_stationsResponse_setsCheapest() async {
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.apiClient = .mock()
            $0.continuousClock = ImmediateClock()
        }
        store.exhaustivity = .off

        await store.send(.reload)
        await store.receive(\.stationsResponse.success)

        // Benzina más barata = Tamoil (id 4, 1.849).
        #expect(store.state.cheapestStationID == 4)
    }

    @Test("sortedStations ordena por precio y por distancia")
    func map_sortedStations_byPriceAndDistance() {
        var state = MapFeature.State()
        state.center = Coordinate(latitude: 41.9028, longitude: 12.4964)
        state.stations = StationFixtures.all

        state.sortOrder = .price
        let byPrice = state.sortedStations.compactMap { $0.cheapest?.price }
        #expect(byPrice == byPrice.sorted())

        state.sortOrder = .distance
        let byDistance = state.sortedStations.map { state.center.distance(to: $0.coordinate) }
        #expect(byDistance == byDistance.sorted())
    }

    @Test("Tocar una estación presenta el detalle")
    func map_stationTapped_presentsDetail() async {
        let station = StationFixtures.all[0]
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        }
        store.exhaustivity = .off

        await store.send(.stationTapped(station))
        #expect(store.state.detail?.stationId == station.id)
        #expect(store.state.detail?.station == station)
    }
}
