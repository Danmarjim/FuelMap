//
//  PaywallFeature.swift
//  FuelMap
//
//  Created on 17/07/2026.
//

import ComposableArchitecture
import Foundation

extension PurchaseError {
    /// Mensaje de usuario (mismo criterio que `APIError.userMessage`).
    var userMessage: String {
        switch self {
        case .productUnavailable:
            return String(localized: "Acquisto non disponibile al momento.")
        case .failedVerification:
            return String(localized: "Non è stato possibile verificare l'acquisto.")
        case .network:
            return String(localized: "Errore di connessione. Riprova.")
        case .purchaseFailed, .restoreFailed, .unknown:
            return String(localized: "Qualcosa è andato storto. Riprova.")
        }
    }
}

/// Paywall del pago único que elimina los anuncios (PREMIUM-001 §P4).
///
/// No toca los anuncios ni el estado premium de la app: al concederse el entitlement,
/// `PurchaseStore` lo emite y `AppFeature` retira el banner (§P2).
@Reducer
struct PaywallFeature {
    @ObservableState
    struct State: Equatable {
        var product: PremiumProduct?
        var isLoading = false
        var isPurchasing = false
        var isRestoring = false
        var errorMessage: String?
        /// Compra en espera de aprobación externa (SCA / "Chiedi di acquistare").
        var isPending = false

        var isBusy: Bool { isPurchasing || isRestoring }
    }

    enum Action: Equatable {
        case onAppear
        case productResponse(Result<PremiumProduct, PurchaseError>)
        case purchaseTapped
        case purchaseResponse(Result<PurchaseOutcome, PurchaseError>)
        case restoreTapped
        case restoreResponse(Result<Bool, PurchaseError>)
        case closeTapped
    }

    @Dependency(\.purchaseClient) var purchaseClient
    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.product == nil else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    do {
                        await send(.productResponse(.success(try await purchaseClient.premiumProduct())))
                    } catch {
                        await send(.productResponse(.failure(PurchaseError.from(error))))
                    }
                }

            case let .productResponse(.success(product)):
                state.isLoading = false
                state.product = product
                return .none

            case let .productResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.userMessage
                return .none

            case .purchaseTapped:
                guard !state.isBusy else { return .none }
                state.isPurchasing = true
                state.errorMessage = nil
                state.isPending = false
                return .run { send in
                    do {
                        await send(.purchaseResponse(.success(try await purchaseClient.purchase())))
                    } catch {
                        await send(.purchaseResponse(.failure(PurchaseError.from(error))))
                    }
                }

            case .purchaseResponse(.success(.success)):
                state.isPurchasing = false
                // El banner ya lo retira AppFeature al recibir el entitlement (§P2).
                return .run { _ in await dismiss() }

            case .purchaseResponse(.success(.userCancelled)):
                // Cancelar no es un error: no se muestra nada.
                state.isPurchasing = false
                return .none

            case .purchaseResponse(.success(.pending)):
                state.isPurchasing = false
                state.isPending = true
                return .none

            case let .purchaseResponse(.failure(error)):
                state.isPurchasing = false
                state.errorMessage = error.userMessage
                return .none

            case .restoreTapped:
                guard !state.isBusy else { return .none }
                state.isRestoring = true
                state.errorMessage = nil
                return .run { send in
                    do {
                        await send(.restoreResponse(.success(try await purchaseClient.restore())))
                    } catch {
                        await send(.restoreResponse(.failure(PurchaseError.from(error))))
                    }
                }

            case let .restoreResponse(.success(restored)):
                state.isRestoring = false
                guard restored else {
                    state.errorMessage = String(localized: "Nessun acquisto da ripristinare.")
                    return .none
                }
                return .run { _ in await dismiss() }

            case let .restoreResponse(.failure(error)):
                state.isRestoring = false
                state.errorMessage = error.userMessage
                return .none

            case .closeTapped:
                return .run { _ in await dismiss() }
            }
        }
    }
}
