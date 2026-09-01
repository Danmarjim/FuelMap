//
//  OnboardingFeature.swift
//  FuelMap
//
//  Created on 01/09/2026.
//

import ComposableArchitecture
import CoreLocation

/// Onboarding de primer lanzamiento (RELEASE-001 Fase 1): propuesta de valor +
/// priming de ubicación antes del prompt del sistema. Sin pitch de premium — el
/// onboarding vende la app, no la compra (coherente con ADR-006).
@Reducer
struct OnboardingFeature {
    enum Page: Hashable, CaseIterable {
        case welcome
        case location
    }

    /// Fuera de `Action` por el límite de anidamiento de SwiftLint (1 nivel).
    enum Delegate: Equatable {
        /// El onboarding es el único dueño del prompt de ubicación: lleva el status
        /// ya resuelto para que `MapFeature` no vuelva a llamar a
        /// `requestWhenInUse()` — antes, "Salta" terminaba el onboarding sin pedir
        /// nada, y el alert salía de todos modos al llegar al mapa, sin el priming
        /// que la página 2 existe para dar (review RELEASE-001 F1-F2, C-1).
        case finished(CLAuthorizationStatus)
    }

    @ObservableState
    struct State: Equatable {
        var page: Page = .welcome
    }

    enum Action: Equatable {
        /// Navegación entre páginas, venga del botón "Continua" o del swipe del
        /// `TabView` — es el mismo gesto para el reducer.
        case pageChanged(Page)
        /// "Salta" y "Attiva posizione" hacen lo mismo (piden el permiso y
        /// terminan) — la copy dice "Salta la explicación", no "no me lo pidas".
        /// Dos acciones distintas por claridad de intención en el código/tests, no
        /// porque el comportamiento difiera.
        case skipTapped
        case enableLocationTapped
        case locationResponse(CLAuthorizationStatus)
        case delegate(Delegate)
    }

    @Dependency(\.locationClient) var locationClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .pageChanged(page):
                state.page = page
                return .none

            case .skipTapped, .enableLocationTapped:
                return .run { send in
                    let status = await locationClient.requestWhenInUse()
                    await send(.locationResponse(status))
                }

            case let .locationResponse(status):
                return .send(.delegate(.finished(status)))

            case .delegate:
                return .none
            }
        }
    }
}
