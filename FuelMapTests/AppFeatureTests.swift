//
//  AppFeatureTests.swift
//  FuelMapTests
//
//  Created on 04/06/2026.
//

import ComposableArchitecture
import Testing

@testable import FuelMap

@MainActor
struct AppFeatureTests {
    @Test("AppFeature se inicializa y procesa onAppear sin efectos pendientes")
    func appFeature_onAppear_noPendingEffects() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }
        await store.send(.onAppear)
    }
}
