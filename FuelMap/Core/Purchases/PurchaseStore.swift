//
//  PurchaseStore.swift
//  FuelMap
//
//  Created on 17/07/2026.
//

import ComposableArchitecture
import StoreKit

/// Propietario del estado de compra: cachea el entitlement para lectura síncrona y
/// escucha `Transaction.updates` (compras, restauraciones desde otro dispositivo,
/// family sharing y **reembolsos**) (PREMIUM-001 §P1).
///
/// Sin servidor propio: la verdad es siempre `Transaction.currentEntitlements`; esta
/// clase solo mantiene un espejo consultable sin `await`.
final class PurchaseStore: Sendable {
    static let shared = PurchaseStore()

    /// Último entitlement conocido, accesible de forma síncrona y thread-safe.
    /// Mismo patrón que `LocationCoordinator.statusBox`.
    private let entitlementBox = LockIsolated(false)
    private let observers = LockIsolated<[UUID: AsyncStream<Bool>.Continuation]>([:])
    private let listenTask = LockIsolated<Task<Void, Never>?>(nil)

    var isPremium: Bool { entitlementBox.value }

    // MARK: - Entitlement

    /// Recalcula el entitlement desde StoreKit. `currentEntitlements` es lectura local
    /// (no red), por lo que puede llamarse en el arranque sin coste perceptible.
    @discardableResult
    func refresh() async -> Bool {
        var premium = false
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result,
                  transaction.productID == PurchaseClient.premiumProductID,
                  transaction.revocationDate == nil
            else { continue }
            premium = true
        }
        setPremium(premium)
        return premium
    }

    /// Stream del entitlement. Suscribirse arranca el listener de `Transaction.updates`.
    func updates() -> AsyncStream<Bool> {
        startObserving()
        return AsyncStream { continuation in
            let id = UUID()
            observers.withValue { $0[id] = continuation }
            continuation.onTermination = { [observers] _ in
                observers.withValue { $0[id] = nil }
            }
        }
    }

    // MARK: - Compra

    /// Presenta la hoja de compra de Apple. `@MainActor`: presenta UI del sistema.
    @MainActor
    func purchase() async throws -> PurchaseOutcome {
        let product = try await storeProduct()
        let result: Product.PurchaseResult
        do {
            result = try await product.purchase()
        } catch {
            throw PurchaseError.purchaseFailed
        }

        switch result {
        case let .success(verification):
            guard case let .verified(transaction) = verification else {
                throw PurchaseError.failedVerification
            }
            await transaction.finish()
            await refresh()
            return .success
        case .userCancelled:
            return .userCancelled
        case .pending:
            // Compra en espera (p. ej. SCA o "Ask to Buy"): llegará por `Transaction.updates`.
            return .pending
        @unknown default:
            throw PurchaseError.unknown
        }
    }

    /// Restaura compras. `@MainActor`: puede pedir credenciales de App Store.
    @MainActor
    func restore() async throws -> Bool {
        do {
            try await AppStore.sync()
        } catch {
            throw PurchaseError.restoreFailed
        }
        return await refresh()
    }

    func premiumProduct() async throws -> PremiumProduct {
        let product = try await storeProduct()
        return PremiumProduct(id: product.id, displayPrice: product.displayPrice)
    }

    // MARK: - Private helpers

    /// El precio nunca se cachea entre sesiones ni se codifica en la app: `displayPrice`
    /// depende del storefront y la moneda del usuario.
    private func storeProduct() async throws -> Product {
        let products: [Product]
        do {
            products = try await Product.products(for: [PurchaseClient.premiumProductID])
        } catch {
            throw PurchaseError.network
        }
        guard let product = products.first else { throw PurchaseError.productUnavailable }
        return product
    }

    private func startObserving() {
        listenTask.withValue { task in
            guard task == nil else { return }
            task = Task { [weak self] in
                for await update in Transaction.updates {
                    guard let self else { return }
                    if case let .verified(transaction) = update {
                        await transaction.finish()
                    }
                    await self.refresh()
                }
            }
        }
    }

    /// Publica solo los cambios reales: evita re-disparar efectos en cada `refresh()`.
    private func setPremium(_ value: Bool) {
        let changed = entitlementBox.withValue { current -> Bool in
            guard current != value else { return false }
            current = value
            return true
        }
        guard changed else { return }
        observers.withValue { $0.values.forEach { $0.yield(value) } }
    }
}
