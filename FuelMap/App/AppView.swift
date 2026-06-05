//
//  AppView.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import ComposableArchitecture
import SwiftUI

/// Vista raíz. Aloja el mapa y el banner de ads debajo (fuera del mapa) (RFC §1, §6.4).
struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        VStack(spacing: 0) {
            MapView(store: store.scope(state: \.map, action: \.map))
            if !store.bannerAdUnitID.isEmpty {
                BannerAdView(adUnitID: store.bannerAdUnitID)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
            }
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
