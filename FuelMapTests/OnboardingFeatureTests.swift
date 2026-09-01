//
//  OnboardingFeatureTests.swift
//  FuelMapTests
//
//  Created on 01/09/2026.
//

import ComposableArchitecture
import CoreLocation
import Testing

@testable import FuelMap

@MainActor
struct OnboardingFeatureTests {
    @Test("Continuar avanza de bienvenida a ubicación")
    func onboarding_continue_advancesToLocationPage() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }

        await store.send(.pageChanged(.location)) {
            $0.page = .location
        }
    }

    @Test("El swipe del TabView navega igual que el botón Continua")
    func onboarding_swipeBack_returnsToWelcomePage() async {
        let store = TestStore(initialState: OnboardingFeature.State(page: .location)) {
            OnboardingFeature()
        }

        await store.send(.pageChanged(.welcome)) {
            $0.page = .welcome
        }
    }

    @Test(
        """
        Saltar también pide el permiso (la copy dice "Salta", no "no me lo pidas") y
        termina el onboarding con el status ya resuelto — MapFeature no debe volver a
        pedirlo (review RELEASE-001 F1-F2, C-1).
        """
    )
    func onboarding_skip_alsoRequestsPermissionThenFinishesWithStatus() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        } withDependencies: {
            $0.locationClient.requestWhenInUse = { .denied }
        }

        await store.send(.skipTapped)
        await store.receive(.locationResponse(.denied))
        await store.receive(.delegate(.finished(.denied)))
    }

    @Test("Activar ubicación pide el permiso y termina el onboarding con el status resuelto")
    func onboarding_enableLocation_requestsPermissionThenFinishesWithStatus() async {
        let store = TestStore(initialState: OnboardingFeature.State(page: .location)) {
            OnboardingFeature()
        } withDependencies: {
            $0.locationClient.requestWhenInUse = { .authorizedWhenInUse }
        }

        await store.send(.enableLocationTapped)
        await store.receive(.locationResponse(.authorizedWhenInUse))
        await store.receive(.delegate(.finished(.authorizedWhenInUse)))
    }
}
