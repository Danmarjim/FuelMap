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
    @Test("El estado raíz compone MapFeature con sus valores por defecto")
    func appFeature_composesMapByDefault() {
        let state = AppFeature.State()
        #expect(state.map.filters.fuel == .benzina)
        #expect(state.map.stations.isEmpty)
    }

    @Test("onAppear pide consentimiento y luego arranca el SDK de ads")
    func appFeature_onAppear_consentThenStart() async {
        let calls = LockIsolated<[String]>([])
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.adClient = AdClient(
                start: { calls.withValue { $0.append("start") } },
                requestConsent: { calls.withValue { $0.append("consent") } },
                bannerAdUnitID: { "test" }
            )
        }

        await store.send(.onAppear)
        await store.finish()

        #expect(calls.value == ["consent", "start"])
    }
}
