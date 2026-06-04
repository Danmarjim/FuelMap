//
//  FiltersFeatureTests.swift
//  FuelMapTests
//
//  Created on 04/06/2026.
//

import ComposableArchitecture
import Testing

@testable import FuelMap

@MainActor
struct FiltersFeatureTests {

    @Test("Toggle self-only actualiza el estado")
    func filters_toggleSelfOnly_updatesState() async {
        let store = TestStore(initialState: FiltersFeature.State()) {
            FiltersFeature()
        }
        await store.send(.binding(.set(\.selfOnly, true))) {
            $0.selfOnly = true
        }
    }

    @Test("Cambiar combustible actualiza el estado")
    func filters_changeFuel_updatesState() async {
        let store = TestStore(initialState: FiltersFeature.State()) {
            FiltersFeature()
        }
        await store.send(.binding(.set(\.fuel, .gasolio))) {
            $0.fuel = .gasolio
        }
    }

    @Test("Cambiar radio actualiza el estado")
    func filters_changeRadius_updatesState() async {
        let store = TestStore(initialState: FiltersFeature.State()) {
            FiltersFeature()
        }
        await store.send(.binding(.set(\.radiusKm, 10))) {
            $0.radiusKm = 10
        }
    }
}
