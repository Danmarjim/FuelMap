//
//  AppFeature.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import ComposableArchitecture

/// Reducer raíz de la app. Compondrá `MapFeature`, `FiltersFeature` y
/// `StationDetailFeature` (RFC §1, §6.2). En FM-1 es un esqueleto vacío.
@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        // Las features hijas se añadirán en FM-7+ (Map), FM-8 (Filters), FM-9 (Detail).
    }

    enum Action {
        // Acciones de composición a definir al integrar las features hijas.
        case onAppear
    }

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .onAppear:
                return .none
            }
        }
    }
}
