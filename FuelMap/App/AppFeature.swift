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
        /// Ad unit del banner. Vacía = sin banner: o no se ha resuelto aún el
        /// entitlement, o el usuario es premium. Evita el parpadeo del banner al
        /// arrancar (PREMIUM-001 §P2).
        var bannerAdUnitID = ""
        var isPremium = false
        /// Hoja de informazioni. Vive aquí y no en `MapFeature` porque necesita
        /// `isPremium`, que es estado de app (PREMIUM-001 §P4).
        var isShowingSettings = false
        @Presents var paywall: PaywallFeature.State?
    }

    enum Action {
        case onAppear
        /// Entitlement resuelto en el arranque.
        case entitlementLoaded(Bool)
        /// Cambio en vivo: compra, restauración desde otro dispositivo, family sharing
        /// o reembolso.
        case entitlementChanged(Bool)
        case settingsDismissed
        case premiumTapped
        case paywall(PresentationAction<PaywallFeature.Action>)
        case map(MapFeature.Action)
    }

    private enum CancelID { case entitlementUpdates }

    @Dependency(\.adClient) var adClient
    @Dependency(\.purchaseClient) var purchaseClient

    var body: some ReducerOf<Self> {
        Scope(state: \.map, action: \.map) {
            MapFeature()
        }
        Reduce { state, action in
            switch action {
            case .onAppear:
                // El entitlement se resuelve ANTES del consentimiento: al usuario premium
                // no le corresponden ni el formulario UMP ni el prompt de ATT, y ambos se
                // piden una sola vez en la vida de la instalación (PREMIUM-001 §P2).
                return .merge(
                    .run { send in
                        await send(.entitlementLoaded(purchaseClient.refreshEntitlement()))
                    },
                    .run { send in
                        for await isPremium in purchaseClient.entitlementUpdates() {
                            await send(.entitlementChanged(isPremium))
                        }
                    }
                    .cancellable(id: CancelID.entitlementUpdates, cancelInFlight: true)
                )

            case let .entitlementLoaded(isPremium):
                state.isPremium = isPremium
                return isPremium ? .none : enableAds(&state)

            case let .entitlementChanged(isPremium):
                guard isPremium != state.isPremium else { return .none }
                state.isPremium = isPremium
                guard !isPremium else {
                    state.bannerAdUnitID = ""
                    return .none
                }
                // Perdió el entitlement (reembolso/revocación): vuelven los anuncios y hay
                // que pedirle el consentimiento que como premium nunca se le pidió.
                return enableAds(&state)

            case .map(.delegate(.settingsTapped)):
                state.isShowingSettings = true
                return .none

            case .settingsDismissed:
                state.isShowingSettings = false
                return .none

            case .premiumTapped:
                // Se cierra la hoja de informazioni antes de abrir el paywall: dos sheets
                // apilados no se presentan bien.
                state.isShowingSettings = false
                state.paywall = PaywallFeature.State()
                return .none

            case .paywall, .map:
                return .none
            }
        }
        .ifLet(\.$paywall, action: \.paywall) {
            PaywallFeature()
        }
    }

    // MARK: - Private Helpers

    /// Activa los anuncios: ad unit + consentimiento (UMP→ATT) antes de arrancar el SDK (RFC §6.4).
    private func enableAds(_ state: inout State) -> Effect<Action> {
        state.bannerAdUnitID = adClient.bannerAdUnitID()
        return .run { _ in
            await adClient.requestConsent()
            await adClient.start()
        }
    }
}
