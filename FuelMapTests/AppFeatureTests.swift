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

    @Test(
        """
        showOnboarding se resuelve en el init (síncrono), no en onAppear: si se
        difiriera, SwiftUI pintaría `MapView` un frame antes de que el reducer lo
        corrigiera y su onAppear dispararía el permiso de ubicación de golpe.
        """
    )
    func appFeature_state_resolvesShowOnboardingSynchronouslyAtInit() {
        let firstLaunch = withDependencies {
            $0.onboardingStorage.hasCompleted = { false }
        } operation: {
            AppFeature.State()
        }
        #expect(firstLaunch.showOnboarding == true)

        let returningUser = withDependencies {
            $0.onboardingStorage.hasCompleted = { true }
        } operation: {
            AppFeature.State()
        }
        #expect(returningUser.showOnboarding == false)
    }

    @Test("Usuario gratuito: onAppear pide consentimiento y luego arranca el SDK de ads")
    func appFeature_onAppear_consentThenStart() async {
        let calls = LockIsolated<[String]>([])
        let (updates, continuation) = AsyncStream.makeStream(of: Bool.self)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.adClient = AdClient(
                start: { calls.withValue { $0.append("start") } },
                requestConsent: { calls.withValue { $0.append("consent") } },
                bannerAdUnitID: { "test" },
                detailAdUnitID: { "test" }
            )
            $0.purchaseClient.refreshEntitlement = { false }
            $0.purchaseClient.entitlementUpdates = { updates }
        }

        await store.send(.onAppear) {
            $0.didAppear = true
        }
        await store.receive(\.entitlementLoaded) {
            $0.bannerAdUnitID = "test"
        }
        continuation.finish()
        await store.finish()

        #expect(calls.value == ["consent", "start"])
    }

    @Test("Primer lanzamiento: el consentimiento de ads espera a que termine el onboarding")
    func appFeature_firstLaunch_defersAdsUntilOnboardingFinishes() async {
        let calls = LockIsolated<[String]>([])
        let (updates, continuation) = AsyncStream.makeStream(of: Bool.self)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.adClient = AdClient(
                start: { calls.withValue { $0.append("start") } },
                requestConsent: { calls.withValue { $0.append("consent") } },
                bannerAdUnitID: { "test" },
                detailAdUnitID: { "test" }
            )
            $0.purchaseClient.refreshEntitlement = { false }
            $0.purchaseClient.entitlementUpdates = { updates }
            $0.onboardingStorage.hasCompleted = { false }
            $0.apiClient = .mock()
        }
        store.exhaustivity = .off

        // Ya en construcción (init de `State`), no como efecto de `.onAppear`.
        #expect(store.state.showOnboarding == true)

        await store.send(.onAppear)
        // El entitlement se resuelve, pero el onboarding sigue en pantalla: no se pide
        // consentimiento ni se muestra banner todavía.
        await store.receive(\.entitlementLoaded)
        #expect(calls.value.isEmpty)
        #expect(store.state.bannerAdUnitID.isEmpty)

        // El status va con el `.finished` — MapFeature no debe volver a pedirlo (C-1).
        await store.send(.onboarding(.delegate(.finished(.denied)))) {
            $0.showOnboarding = false
            $0.bannerAdUnitID = "test"
        }
        await store.receive(\.map.locationPermissionResolved)
        await store.receive(\.map.locationPermissionDenied)
        await store.receive(\.map.stationsResponse.success)
        continuation.finish()
        await store.finish()

        #expect(calls.value == ["consent", "start"])
        #expect(store.state.map.locationPermissionDenied == true)
    }

    @Test(
        """
        Un segundo `.onAppear` (p. ej. si SwiftUI lo reemite al sustituir la rama del
        `Group` en `AppView` cuando termina el onboarding) no repite el consentimiento
        ni relanza el SDK de ads — ancla la regresión de la review RELEASE-001 F1-F2, A-1.
        """
    )
    func appFeature_secondOnAppear_isNoOp() async {
        let calls = LockIsolated<[String]>([])
        let (updates, continuation) = AsyncStream.makeStream(of: Bool.self)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.adClient = AdClient(
                start: { calls.withValue { $0.append("start") } },
                requestConsent: { calls.withValue { $0.append("consent") } },
                bannerAdUnitID: { "test" },
                detailAdUnitID: { "test" }
            )
            $0.purchaseClient.refreshEntitlement = { false }
            $0.purchaseClient.entitlementUpdates = { updates }
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.entitlementLoaded)
        await store.send(.onAppear) // segunda emisión: debe ser un no-op total.
        continuation.finish()
        await store.finish()

        #expect(calls.value == ["consent", "start"])
    }

    @Test("Terminar el onboarding persiste el flag — una regresión que no lo haga pasaría en verde sin este test")
    func appFeature_onboardingFinished_persistsCompletedFlag() async {
        let setCompletedCalls = LockIsolated<Int>(0)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.onboardingStorage.setCompleted = { setCompletedCalls.withValue { $0 += 1 } }
            $0.apiClient = .mock()
        }
        store.exhaustivity = .off

        await store.send(.onboarding(.delegate(.finished(.denied))))

        #expect(setCompletedCalls.value == 1)
    }
}
