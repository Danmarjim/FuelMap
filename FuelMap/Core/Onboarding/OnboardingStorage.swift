//
//  OnboardingStorage.swift
//  FuelMap
//
//  Created on 01/09/2026.
//

import ComposableArchitecture
import Foundation

/// Persistencia del flag de onboarding (RELEASE-001 Fase 1). Preferencia de app, no
/// dato de dominio: `UserDefaults`, no SwiftData.
struct OnboardingStorage: Sendable {
    var hasCompleted: @Sendable () -> Bool
    var setCompleted: @Sendable () -> Void
}

// MARK: - Dependency

extension OnboardingStorage: DependencyKey {
    private static let key = "hasCompletedOnboarding"

    static let liveValue = OnboardingStorage(
        hasCompleted: { UserDefaults.standard.bool(forKey: key) },
        setCompleted: { UserDefaults.standard.set(true, forKey: key) }
    )

    // `true` por defecto: los tests que no son sobre onboarding (la mayoría) deben
    // comportarse como un usuario que ya lo completó, no como un primer lanzamiento.
    // Los tests de onboarding sobreescriben esto a `false` explícitamente.
    static let testValue = OnboardingStorage(
        hasCompleted: { true },
        setCompleted: {}
    )

    static let previewValue = testValue
}

extension DependencyValues {
    var onboardingStorage: OnboardingStorage {
        get { self[OnboardingStorage.self] }
        set { self[OnboardingStorage.self] = newValue }
    }
}
