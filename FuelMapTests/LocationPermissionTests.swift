//
//  LocationPermissionTests.swift
//  FuelMapTests
//
//  Created on 01/09/2026.
//

import ComposableArchitecture
import CoreLocation
import Testing
import UIKit

@testable import FuelMap

/// Extraído de `MapFeatureTests` (`type_body_length`, límite 250 — mismo motivo que
/// llevó a `FavoritePricesTests`).
@MainActor
struct LocationPermissionTests {
    @Test("Permiso denegado: usa el centro por defecto, carga igualmente y marca el banner")
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
        await store.receive(\.locationPermissionDenied)
        await store.receive(\.stationsResponse.success)

        #expect(store.state.center == .italyDefault)
        #expect(!store.state.stations.isEmpty)
        #expect(store.state.locationPermissionDenied == true)
    }

    @Test("Restringido (parental/MDM) también marca el banner de permiso denegado")
    func map_onAppear_restrictedMarksLocationPermissionDenied() async {
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.apiClient = .mock()
            $0.locationClient.requestWhenInUse = { .restricted }
            $0.continuousClock = ImmediateClock()
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.locationPermissionDenied)
        await store.receive(\.stationsResponse.success)

        #expect(store.state.locationPermissionDenied == true)
    }

    @Test("Volver de Ajustes con el permiso ya concedido recupera la ubicación y quita el banner")
    func map_appBecameActive_afterGrantingInSettings_recoversLocation() async {
        let userCoord = Coordinate(latitude: 45.46, longitude: 9.19)
        var state = MapFeature.State()
        state.locationPermissionDenied = true
        let store = TestStore(initialState: state) {
            MapFeature()
        } withDependencies: {
            $0.apiClient = .mock()
            $0.locationClient.authorizationStatus = { .authorizedWhenInUse }
            $0.locationClient.currentLocation = { userCoord }
            $0.continuousClock = ImmediateClock()
        }
        store.exhaustivity = .off

        await store.send(.appBecameActive)
        await store.receive(\.locationResponse)
        await store.receive(\.stationsResponse.success)

        #expect(store.state.center == userCoord)
        #expect(store.state.locationPermissionDenied == false)
    }

    @Test(
        """
        openLocationSettingsTapped abre Ajustes vía `@Dependency(\\.openURL)` — no
        `UIApplication.shared.open` directo en la vista, para que sea testeable y
        pase por el mismo camino que el resto de deep links del proyecto
        (review RELEASE-001 F1-F2, A-7).
        """
    )
    func map_openLocationSettingsTapped_opensSettingsURL() async {
        let opened = LockIsolated<URL?>(nil)
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.openURL = OpenURLEffect { url in
                opened.setValue(url)
                return true
            }
        }

        await store.send(.openLocationSettingsTapped)

        #expect(opened.value?.absoluteString == UIApplication.openSettingsURLString)
    }

    @Test("appBecameActive con ubicación real ya obtenida no vuelve a comprobar el permiso")
    func map_appBecameActive_withRealUserLocation_isNoOp() async {
        var state = MapFeature.State()
        state.userLocation = Coordinate(latitude: 41.9, longitude: 12.5)
        let store = TestStore(initialState: state) {
            MapFeature()
        } withDependencies: {
            $0.locationClient.authorizationStatus = unimplemented(
                "LocationClient.authorizationStatus", placeholder: .notDetermined
            )
        }

        await store.send(.appBecameActive)
    }

    @Test(
        """
        Tras una búsqueda manual (que no toca `userLocation`), volver de Ajustes con el
        permiso ya concedido sigue recuperando la ubicación real — antes el guard miraba
        `locationPermissionDenied`, que la búsqueda manual ya había limpiado, dejando
        este camino sin salida (review RELEASE-001 F1-F2, C-2).
        """
    )
    func map_appBecameActive_afterManualSearch_stillRecoversRealLocation() async {
        let barcelona = Coordinate(latitude: 41.3874, longitude: 2.1686)
        let userCoord = Coordinate(latitude: 45.46, longitude: 9.19)
        var state = MapFeature.State()
        state.center = barcelona // resultado de una búsqueda manual ya resuelta.
        state.locationPermissionDenied = false // la búsqueda manual ya lo había limpiado.
        let store = TestStore(initialState: state) {
            MapFeature()
        } withDependencies: {
            $0.apiClient = .mock()
            $0.locationClient.authorizationStatus = { .authorizedWhenInUse }
            $0.locationClient.currentLocation = { userCoord }
            $0.continuousClock = ImmediateClock()
        }
        store.exhaustivity = .off

        await store.send(.appBecameActive)
        await store.receive(\.locationResponse)
        await store.receive(\.stationsResponse.success)

        #expect(store.state.center == userCoord)
        #expect(store.state.userLocation == userCoord)
    }
}
