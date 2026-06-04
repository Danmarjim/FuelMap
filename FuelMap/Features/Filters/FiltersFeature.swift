//
//  FiltersFeature.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import ComposableArchitecture

/// Filtros del mapa: combustible, self/servito y radio (RFC §6.2).
/// El padre (`MapFeature`) observa los cambios para recargar.
@Reducer
struct FiltersFeature {
    @ObservableState
    struct State: Equatable {
        var fuel: FuelType = .benzina
        var selfOnly = false
        var radiusKm: Double = 5
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
    }
}

/// Opciones de radio (km) ofrecidas en el filtro.
enum RadiusOption {
    static let all: [Double] = [1, 3, 5, 10, 20]
}
