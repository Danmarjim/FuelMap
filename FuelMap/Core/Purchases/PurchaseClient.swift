//
//  PurchaseClient.swift
//  FuelMap
//
//  Created on 17/07/2026.
//

import ComposableArchitecture
import Foundation

/// Producto premium listo para pintar. `displayPrice` viene ya formateado y localizado
/// por StoreKit según el storefront del usuario — **nunca** se codifica el precio en la app.
struct PremiumProduct: Equatable, Sendable {
    let id: String
    let displayPrice: String
}

/// Resultado de un intento de compra. La cancelación del usuario no es un error.
enum PurchaseOutcome: Equatable, Sendable {
    case success
    case userCancelled
    /// En espera de aprobación externa (SCA, "Ask to Buy"): el entitlement llegará
    /// más tarde por `entitlementUpdates`.
    case pending
}

/// Errores de la capa de compras (PREMIUM-001).
enum PurchaseError: Error, Equatable, Sendable {
    /// El producto no existe en el storefront (ID mal configurado, no aprobado aún).
    case productUnavailable
    /// StoreKit no pudo verificar la firma de la transacción.
    case failedVerification
    /// No se pudo consultar el catálogo.
    case network
    case purchaseFailed
    case restoreFailed
    case unknown

    /// Normaliza cualquier error del límite de la dependencia a un caso propio.
    /// Los errores de StoreKit ya se mapean dentro de `PurchaseStore`; esto cubre
    /// cancelaciones de tarea y cualquier error inesperado.
    static func from(_ error: any Error) -> PurchaseError {
        (error as? PurchaseError) ?? .unknown
    }
}

/// Dependencia de compras in-app sobre StoreKit 2 (PREMIUM-001 §P1, ADR-006).
///
/// - `isPremium`: lectura síncrona y thread-safe del último entitlement conocido.
/// - `refreshEntitlement`: recalcula desde `Transaction.currentEntitlements` (lectura local).
/// - `entitlementUpdates`: cambios en vivo — compra, restauración, family sharing y reembolsos.
struct PurchaseClient: Sendable {
    var premiumProduct: @Sendable () async throws -> PremiumProduct
    var purchase: @Sendable () async throws -> PurchaseOutcome
    /// Restaura compras; devuelve el entitlement resultante (`false` = no había compra previa).
    var restore: @Sendable () async throws -> Bool
    var isPremium: @Sendable () -> Bool
    var refreshEntitlement: @Sendable () async -> Bool
    var entitlementUpdates: @Sendable () -> AsyncStream<Bool>
}

extension PurchaseClient {
    /// No-consumible: elimina los anuncios para siempre. Debe coincidir con el ID en
    /// App Store Connect y en `FuelMap.storekit`.
    static let premiumProductID = "com.danmarjim.fuelmap.premium.noads"
}

// MARK: - Dependency

extension PurchaseClient: DependencyKey {
    static var liveValue: PurchaseClient {
        PurchaseClient(
            premiumProduct: { try await PurchaseStore.shared.premiumProduct() },
            purchase: { try await PurchaseStore.shared.purchase() },
            restore: { try await PurchaseStore.shared.restore() },
            isPremium: { PurchaseStore.shared.isPremium },
            refreshEntitlement: { await PurchaseStore.shared.refresh() },
            entitlementUpdates: { PurchaseStore.shared.updates() }
        )
    }

    static var testValue: PurchaseClient {
        PurchaseClient(
            premiumProduct: unimplemented("PurchaseClient.premiumProduct"),
            purchase: unimplemented("PurchaseClient.purchase"),
            restore: unimplemented("PurchaseClient.restore"),
            isPremium: unimplemented("PurchaseClient.isPremium", placeholder: false),
            refreshEntitlement: unimplemented(
                "PurchaseClient.refreshEntitlement", placeholder: false
            ),
            entitlementUpdates: unimplemented(
                "PurchaseClient.entitlementUpdates", placeholder: .never
            )
        )
    }

    static var previewValue: PurchaseClient { .mock() }

    /// Cliente en memoria para previews y tests (sin StoreKit).
    static func mock(isPremium: Bool = false, displayPrice: String = "3,99 €") -> PurchaseClient {
        let box = LockIsolated(isPremium)
        return PurchaseClient(
            premiumProduct: { PremiumProduct(id: premiumProductID, displayPrice: displayPrice) },
            purchase: {
                box.setValue(true)
                return .success
            },
            restore: { box.value },
            isPremium: { box.value },
            refreshEntitlement: { box.value },
            entitlementUpdates: { .never }
        )
    }
}

extension DependencyValues {
    var purchaseClient: PurchaseClient {
        get { self[PurchaseClient.self] }
        set { self[PurchaseClient.self] = newValue }
    }
}
