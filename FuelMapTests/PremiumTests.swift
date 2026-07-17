//
//  PremiumTests.swift
//  FuelMapTests
//
//  Created on 17/07/2026.
//

import ComposableArchitecture
import Testing

@testable import FuelMap

/// Caminos premium del reducer raíz (PREMIUM-001 §P2).
/// Suite aparte de `AppFeatureTests` para no romper `type_body_length` (250).
@MainActor
struct PremiumTests {
    /// `AdClient` que hace fallar el test si alguien toca los anuncios.
    private static func forbiddenAdClient() -> AdClient {
        AdClient(
            start: unimplemented("AdClient.start"),
            requestConsent: unimplemented("AdClient.requestConsent"),
            bannerAdUnitID: unimplemented("AdClient.bannerAdUnitID", placeholder: ""),
            detailAdUnitID: unimplemented("AdClient.detailAdUnitID", placeholder: "")
        )
    }

    /// Registra el orden de las llamadas de anuncios.
    private static func recordingAdClient(_ calls: LockIsolated<[String]>) -> AdClient {
        AdClient(
            start: { calls.withValue { $0.append("start") } },
            requestConsent: { calls.withValue { $0.append("consent") } },
            bannerAdUnitID: { "test" },
            detailAdUnitID: { "test" }
        )
    }

    @Test("Premium al arrancar: ni banner, ni consentimiento UMP, ni prompt de ATT")
    func premium_onAppear_noAdsNoConsent() async {
        let (updates, continuation) = AsyncStream.makeStream(of: Bool.self)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            // Cualquier toque a los anuncios revienta el test.
            $0.adClient = Self.forbiddenAdClient()
            $0.purchaseClient.refreshEntitlement = { true }
            $0.purchaseClient.entitlementUpdates = { updates }
        }

        await store.send(.onAppear)
        await store.receive(\.entitlementLoaded) {
            $0.isPremium = true
        }
        continuation.finish()
        await store.finish()

        #expect(store.state.bannerAdUnitID.isEmpty)
    }

    @Test("Comprar durante la sesión retira el banner sin reiniciar la app")
    func purchase_removesBannerLive() async {
        let calls = LockIsolated<[String]>([])
        let (updates, continuation) = AsyncStream.makeStream(of: Bool.self)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.adClient = Self.recordingAdClient(calls)
            $0.purchaseClient.refreshEntitlement = { false }
            $0.purchaseClient.entitlementUpdates = { updates }
        }

        await store.send(.onAppear)
        await store.receive(\.entitlementLoaded) {
            $0.bannerAdUnitID = "test"
        }

        continuation.yield(true)
        await store.receive(\.entitlementChanged) {
            $0.isPremium = true
            $0.bannerAdUnitID = ""
        }
        continuation.finish()
        await store.finish()

        // El consentimiento se pidió una sola vez, cuando era gratuito.
        #expect(calls.value == ["consent", "start"])
    }

    @Test("Un reembolso devuelve los anuncios y pide el consentimiento que nunca se pidió")
    func refund_restoresAdsAndAsksConsent() async {
        let calls = LockIsolated<[String]>([])
        let (updates, continuation) = AsyncStream.makeStream(of: Bool.self)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.adClient = Self.recordingAdClient(calls)
            $0.purchaseClient.refreshEntitlement = { true }
            $0.purchaseClient.entitlementUpdates = { updates }
        }

        await store.send(.onAppear)
        await store.receive(\.entitlementLoaded) {
            $0.isPremium = true
        }
        // Arrancó como premium: no se le pidió consentimiento.
        #expect(calls.value.isEmpty)

        continuation.yield(false)
        await store.receive(\.entitlementChanged) {
            $0.isPremium = false
            $0.bannerAdUnitID = "test"
        }
        continuation.finish()
        await store.finish()

        #expect(calls.value == ["consent", "start"])
    }

    @Test("Premium: la card de detalle tampoco pide su ad unit")
    func premium_detail_hasNoAd() async {
        let station = StationFixtures.all[0]
        let store = TestStore(
            initialState: StationDetailFeature.State(stationId: station.id, station: station)
        ) {
            StationDetailFeature()
        } withDependencies: {
            $0.apiClient = .mock()
            $0.adClient = Self.forbiddenAdClient()
            $0.purchaseClient.isPremium = { true }
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.stationResponse.success)

        #expect(store.state.adUnitID.isEmpty)
    }

    @Test("Un cambio de entitlement redundante no rehace el consentimiento")
    func redundantEntitlementChange_isIgnored() async {
        let calls = LockIsolated<[String]>([])
        let (updates, continuation) = AsyncStream.makeStream(of: Bool.self)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.adClient = Self.recordingAdClient(calls)
            $0.purchaseClient.refreshEntitlement = { false }
            $0.purchaseClient.entitlementUpdates = { updates }
        }

        await store.send(.onAppear)
        await store.receive(\.entitlementLoaded) {
            $0.bannerAdUnitID = "test"
        }

        // `refresh()` en el arranque puede emitir al stream el mismo valor que ya se
        // aplicó: no debe re-disparar consent/start.
        continuation.yield(false)
        await store.receive(\.entitlementChanged)
        continuation.finish()
        await store.finish()

        #expect(calls.value == ["consent", "start"])
    }
}
