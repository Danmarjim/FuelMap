//
//  AppView.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import ComposableArchitecture
import SwiftUI

/// Vista raíz. Aloja el mapa (RFC §1).
struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        MapView(store: store.scope(state: \.map, action: \.map))
    }
}

#Preview {
    AppView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
