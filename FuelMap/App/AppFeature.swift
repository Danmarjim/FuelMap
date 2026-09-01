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
        /// `true` hasta que el usuario termina (o salta) el onboarding de primer
        /// lanzamiento. Resuelto aquí, en el `init()` — a diferencia del entitlement
        /// premium (que sí espera a `.onAppear` porque StoreKit es async), la lectura
        /// de `onboardingStorage` es síncrona y sin red. Diferirla a `.onAppear`
        /// dejaba un primer frame con `showOnboarding == false`: SwiftUI pintaba
        /// `mainContent` (con `MapView`) antes de que el reducer corrigiera el valor,
        /// y el `onAppear` de `MapView` disparaba el permiso de ubicación de golpe.
        var showOnboarding: Bool
        var onboarding = OnboardingFeature.State()
        /// Guarda de idempotencia: el `.onAppear` de `AppView` cuelga de un `Group`
        /// cuyo hijo cambia (onboarding → mapa); si SwiftUI llegara a re-emitirlo al
        /// sustituir la rama, sin esto se relanzaría `refreshEntitlement()` y, peor,
        /// `enableAds` una segunda vez (`requestConsent()`/`AdSDK.start()` duplicados
        /// — ATT concurrente es comportamiento no definido). Mismo patrón que
        /// `MapFeature.didRequestLocation` (review RELEASE-001 F1-F2, A-1).
        var didAppear = false

        init() {
            @Dependency(\.onboardingStorage) var onboardingStorage
            self.showOnboarding = !onboardingStorage.hasCompleted()
        }
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
        case onboarding(OnboardingFeature.Action)
    }

    private enum CancelID { case entitlementUpdates }

    @Dependency(\.adClient) var adClient
    @Dependency(\.purchaseClient) var purchaseClient
    @Dependency(\.onboardingStorage) var onboardingStorage

    var body: some ReducerOf<Self> {
        Scope(state: \.map, action: \.map) {
            MapFeature()
        }
        Scope(state: \.onboarding, action: \.onboarding) {
            OnboardingFeature()
        }
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.didAppear else { return .none }
                state.didAppear = true
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
                // Si el onboarding sigue en pantalla, no lanzar el consentimiento UMP/ATT
                // todavía: apilar el formulario GDPR sobre el onboarding es mala UX. Se
                // retoma en `.onboarding(.delegate(.finished))`.
                guard !isPremium, !state.showOnboarding else { return .none }
                return enableAds(&state)

            case let .entitlementChanged(isPremium):
                guard isPremium != state.isPremium else { return .none }
                state.isPremium = isPremium
                guard !isPremium else {
                    state.bannerAdUnitID = ""
                    return .none
                }
                // Perdió el entitlement (reembolso/revocación): vuelven los anuncios y hay
                // que pedirle el consentimiento que como premium nunca se le pidió.
                guard !state.showOnboarding else { return .none }
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

            case let .onboarding(.delegate(.finished(status))):
                state.showOnboarding = false
                onboardingStorage.setCompleted()
                // El onboarding ya resolvió el permiso (concedido, denegado o
                // saltado-pero-pedido) — se reenvía para que `MapFeature.onAppear`
                // no vuelva a llamar a `requestWhenInUse()` (review C-1).
                let locationEffect = Effect<Action>.send(.map(.locationPermissionResolved(status)))
                // Retoma el consentimiento/ads que quedó pendiente de `.entitlementLoaded`
                // mientras el onboarding tapaba la pantalla.
                guard !state.isPremium, state.bannerAdUnitID.isEmpty else { return locationEffect }
                return .merge(locationEffect, enableAds(&state))

            case .paywall, .map, .onboarding:
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
