//
//  AppFeatureTests.swift
//  FuelMapTests
//
//  Created on 04/06/2026.
//

import Testing

@testable import FuelMap

struct AppFeatureTests {
    @Test("El estado raíz compone MapFeature con sus valores por defecto")
    func appFeature_composesMapByDefault() {
        let state = AppFeature.State()
        #expect(state.map.fuel == .benzina)
        #expect(state.map.stations.isEmpty)
    }
}
