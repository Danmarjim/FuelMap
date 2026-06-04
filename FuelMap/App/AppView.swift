//
//  AppView.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import ComposableArchitecture
import SwiftUI

/// Vista raíz. En FM-1 muestra un placeholder; alojará el `MapView` en FM-7.
struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        ContentUnavailableView {
            Label("FuelMap", systemImage: "fuelpump.fill")
        } description: {
            Text("Mapa de gasolineras italianas y precios — en construcción.")
        }
        .onAppear { store.send(.onAppear) }
    }
}

#Preview {
    AppView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
