//
//  PaywallFeatureTests.swift
//  FuelMapTests
//
//  Created on 17/07/2026.
//

import ComposableArchitecture
import Testing

@testable import FuelMap

/// Paywall del pago único (PREMIUM-001 §P4).
@MainActor
struct PaywallFeatureTests {
    /// `nonisolated`: se lee desde los closures `@Sendable` de las dependencias.
    private nonisolated static let product = PremiumProduct(
        id: PurchaseClient.premiumProductID,
        displayPrice: "3,99 €"
    )

    @Test("onAppear carga el producto con el precio que da StoreKit")
    func paywall_onAppear_loadsProduct() async {
        let store = TestStore(initialState: PaywallFeature.State()) {
            PaywallFeature()
        } withDependencies: {
            $0.purchaseClient.premiumProduct = { Self.product }
        }

        await store.send(.onAppear) { $0.isLoading = true }
        await store.receive(\.productResponse.success) {
            $0.isLoading = false
            $0.product = Self.product
        }
    }

    @Test("Si el producto no está disponible se muestra el error, no un precio inventado")
    func paywall_productFailure_showsError() async {
        let store = TestStore(initialState: PaywallFeature.State()) {
            PaywallFeature()
        } withDependencies: {
            $0.purchaseClient.premiumProduct = { throw PurchaseError.productUnavailable }
        }

        await store.send(.onAppear) { $0.isLoading = true }
        await store.receive(\.productResponse.failure) {
            $0.isLoading = false
            $0.errorMessage = PurchaseError.productUnavailable.userMessage
        }
        #expect(store.state.product == nil)
    }

    @Test("Cancelar la compra no deja error visible")
    func paywall_userCancelled_isSilent() async {
        let store = TestStore(initialState: PaywallFeature.State(product: Self.product)) {
            PaywallFeature()
        } withDependencies: {
            $0.purchaseClient.purchase = { .userCancelled }
        }

        await store.send(.purchaseTapped) { $0.isPurchasing = true }
        await store.receive(\.purchaseResponse.success) { $0.isPurchasing = false }

        #expect(store.state.errorMessage == nil)
    }

    @Test("Una compra en espera (SCA) no se trata como éxito ni como error")
    func paywall_pending_showsNotice() async {
        let store = TestStore(initialState: PaywallFeature.State(product: Self.product)) {
            PaywallFeature()
        } withDependencies: {
            $0.purchaseClient.purchase = { .pending }
        }

        await store.send(.purchaseTapped) { $0.isPurchasing = true }
        await store.receive(\.purchaseResponse.success) {
            $0.isPurchasing = false
            $0.isPending = true
        }

        #expect(store.state.errorMessage == nil)
    }

    @Test("Restaurar sin compras previas avisa en vez de cerrar la hoja")
    func paywall_restoreWithoutPurchase_warns() async {
        let store = TestStore(initialState: PaywallFeature.State(product: Self.product)) {
            PaywallFeature()
        } withDependencies: {
            $0.purchaseClient.restore = { false }
        }

        await store.send(.restoreTapped) { $0.isRestoring = true }
        await store.receive(\.restoreResponse.success) {
            $0.isRestoring = false
            $0.errorMessage = String(localized: "Nessun acquisto da ripristinare.")
        }
    }

    @Test("Con una compra en curso, volver a pulsar no lanza una segunda compra")
    func paywall_doubleTap_isIgnored() async {
        let purchases = LockIsolated(0)
        // La compra debe seguir *en vuelo* al segundo toque: con un mock que responde al
        // instante, la respuesta llega antes y el guard no se estaría probando.
        let clock = TestClock()
        let store = TestStore(initialState: PaywallFeature.State(product: Self.product)) {
            PaywallFeature()
        } withDependencies: {
            $0.purchaseClient.purchase = {
                purchases.withValue { $0 += 1 }
                try await clock.sleep(for: .seconds(1))
                return .userCancelled
            }
        }

        await store.send(.purchaseTapped) { $0.isPurchasing = true }
        await store.send(.purchaseTapped)
        await clock.advance(by: .seconds(1))
        await store.receive(\.purchaseResponse.success) { $0.isPurchasing = false }

        #expect(purchases.value == 1)
    }
}
