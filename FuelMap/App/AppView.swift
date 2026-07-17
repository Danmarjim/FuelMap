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
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        VStack(spacing: 0) {
            MapView(store: store.scope(state: \.map, action: \.map))
            if !store.bannerAdUnitID.isEmpty {
                BannerAdView(adUnitID: store.bannerAdUnitID)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(Color(.surfaceSecondary))
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color(.separator)).frame(height: 1)
                    }
            }
        }
        .sheet(isPresented: Binding(
            get: { store.isShowingSettings },
            set: { if !$0 { store.send(.settingsDismissed) } }
        )) {
            SettingsView(
                isPremium: store.isPremium,
                onPremiumTapped: { store.send(.premiumTapped) },
                onClose: { store.send(.settingsDismissed) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $store.scope(state: \.paywall, action: \.paywall)) { paywallStore in
            PaywallView(store: paywallStore)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
