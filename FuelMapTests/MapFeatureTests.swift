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
        await store.send(.mapCameraChanged(center: first, span: 0.08))
        await store.send(.mapCameraChanged(center: second, span: 0.08))

        await clock.advance(by: .milliseconds(400))
        await store.receive(\.stationsResponse.success)

        #expect(store.state.center == second)
    }

    @Test("Jitter de centro no recarga; el span (zoom) sí se actualiza")
    func map_cameraChanged_ignoresJitterButUpdatesSpan() async {
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.apiClient = .mock()
            $0.continuousClock = ImmediateClock()
        }
        // Jitter de centro dentro del epsilon (0.0005) respecto a Roma: solo cambia el
        // span (para reclusterizar), sin recarga ni cambio de centro (aserción exhaustiva).
        let jitter = Coordinate(latitude: 41.9030, longitude: 12.4966)
        await store.send(.mapCameraChanged(center: jitter, span: 0.05)) {
            $0.span = 0.05
        }
    }

    @Test("clusterTapped acerca el zoom y recentra en el cluster")
    func map_clusterTapped_zoomsIn() async {
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        }
        let cluster = StationCluster(
            id: "0:0", coordinate: Coordinate(latitude: 45.0, longitude: 9.0),
            count: 5, cheapestPrice: nil
        )
        await store.send(.clusterTapped(cluster)) {
            $0.span = 0.08 / 3
            $0.recenter = cluster.coordinate
        }
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

    @Test("loadFavorites puebla la lista de favoritos")
    func map_loadFavorites_populates() async {
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.favoritesClient.all = {
                [FavoriteStationInfo(id: 1, name: "Preferito", coordinate: .italyDefault)]
            }
        }
        store.exhaustivity = .off

        await store.send(.loadFavorites)
        await store.receive(\.favoritesResponse)

        #expect(store.state.favorites.map(\.id) == [1])
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

    @Test("sortedStations ordena por precio y por distancia (desde la ubicación del usuario)")
    func map_sortedStations_byPriceAndDistance() {
        var state = MapFeature.State()
        state.center = Coordinate(latitude: 45.0, longitude: 9.0)        // centro del mapa
        state.userLocation = Coordinate(latitude: 41.9028, longitude: 12.4964) // usuario
        state.stations = StationFixtures.all

        state.sortOrder = .price
        let byPrice = state.sortedStations.compactMap { $0.cheapest?.price }
        #expect(byPrice == byPrice.sorted())

        // La distancia se mide desde la ubicación del usuario, no desde el centro.
        state.sortOrder = .distance
        let origin = state.distanceOrigin
        #expect(origin == state.userLocation)
        let byDistance = state.sortedStations.map { origin.distance(to: $0.coordinate) }
        #expect(byDistance == byDistance.sorted())
    }

    @Test("recenter se consume y permite reseleccionar el mismo destino")
    func map_recenter_isConsumable() async {
        let station = StationFixtures.all[0]
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        }

        await store.send(.recenterOnStation(station)) {
            $0.recenter = station.coordinate
        }
        await store.send(.recenterHandled) {
            $0.recenter = nil
        }
        // Reseleccionar el mismo destino vuelve a fijar recenter (nil → coord).
        await store.send(.recenterOnStation(station)) {
            $0.recenter = station.coordinate
        }
    }

    @Test("Seleccionar en la lista recentra y abre el detalle tras cerrar el sheet")
    func map_stationSelectedFromList_recentersThenOpensDetail() async {
        let clock = TestClock()
        let station = StationFixtures.all[0]
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }
        store.exhaustivity = .off

        await store.send(.stationSelectedFromList(station))
        #expect(store.state.recenter == station.coordinate)

        await clock.advance(by: .milliseconds(350))
        await store.receive(\.stationTapped)
        #expect(store.state.detail?.stationId == station.id)
        #expect(store.state.detail?.selectedFuel == store.state.filters.fuel)
    }

    @Test("Seleccionar un favorito recentra y abre el detalle")
    func map_favoriteSelected_recentersThenOpensDetail() async {
        let clock = TestClock()
        let favorite = FavoriteStationInfo(
            id: 7, name: "Mi gasolinera", coordinate: Coordinate(latitude: 45.0, longitude: 9.0)
        )
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }
        store.exhaustivity = .off

        await store.send(.favoriteSelected(favorite))
        #expect(store.state.recenter == favorite.coordinate)

        await clock.advance(by: .milliseconds(350))
        await store.receive(\.stationTapped)
        #expect(store.state.detail?.stationId == favorite.id)
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
