//
//  AppFeature.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import ComposableArchitecture

/// Reducer raíz de la app. Compone las features (RFC §1).
@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var map = MapFeature.State()
        var bannerAdUnitID = ""
    }

    enum Action {
        case onAppear
        case map(MapFeature.Action)
    }

    @Dependency(\.adClient) var adClient

    var body: some ReducerOf<Self> {
        Scope(state: \.map, action: \.map) {
            MapFeature()
        }
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.bannerAdUnitID = adClient.bannerAdUnitID()
                // Consentimiento (UMP→ATT) y luego arranque del SDK de ads (RFC §6.4).
                return .run { _ in
                    await adClient.requestConsent()
                    await adClient.start()
                }

            case .map:
                return .none
            }
        }
    }
}
