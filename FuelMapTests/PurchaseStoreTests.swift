//
//  PurchaseStoreTests.swift
//  FuelMapTests
//
//  Created on 17/07/2026.
//

import StoreKitTest
import Testing

@testable import FuelMap

/// Ejercita `PurchaseStore` contra StoreKit real (`SKTestSession` sobre `FuelMap.storekit`).
/// Serializada: `PurchaseStore.shared` y la sesión de StoreKit son estado global de proceso.
@Suite("PurchaseStore contra StoreKit local", .serialized)
struct PurchaseStoreTests {
    /// Sesión limpia por test: sin transacciones previas y sin diálogos de confirmación.
    private func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "FuelMap")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        return session
    }

    @Test("El producto premium se lee del storefront con su precio localizado")
    func premiumProductLoads() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let product = try await PurchaseStore.shared.premiumProduct()

        #expect(product.id == PurchaseClient.premiumProductID)
        #expect(!product.displayPrice.isEmpty)
    }

    @Test("Sin compra previa el usuario no es premium")
    func noEntitlementByDefault() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let isPremium = await PurchaseStore.shared.refresh()

        #expect(isPremium == false)
        #expect(PurchaseStore.shared.isPremium == false)
    }

    @Test("Comprar concede el entitlement y lo deja legible de forma síncrona")
    func purchaseGrantsEntitlement() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        try await session.buyProduct(identifier: PurchaseClient.premiumProductID)
        let isPremium = await PurchaseStore.shared.refresh()

        #expect(isPremium)
        #expect(PurchaseStore.shared.isPremium)
    }

    // El camino de reembolso no se cubre aquí: `SKTestSession.refundTransaction` no
    // propaga la revocación a `Transaction.currentEntitlements` (la transacción sigue
    // presente con `revocationDate == nil`), así que el test solo probaría el simulador
    // de StoreKit, no nuestro código. La conducta que importa —al perder el entitlement
    // vuelven los ads y se pide consentimiento— se dirige desde `AppFeature` con un
    // `entitlementUpdates` controlado (PREMIUM-001 §P2/§P7).
}
