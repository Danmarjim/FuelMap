//
//  FavoritesClient.swift
//  FuelMap
//
//  Created on 05/06/2026.
//

import ComposableArchitecture
import Foundation
import SwiftData

/// Datos Sendable de una estación favorita (cruzan el límite del actor / dependencia).
struct FavoriteStationInfo: Equatable, Sendable, Identifiable {
    let id: Int
    let name: String
    let coordinate: Coordinate
}

/// Entrada para marcar/desmarcar un favorito.
struct FavoriteInput: Equatable, Sendable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
}

/// Dependencia de favoritos locales (FM-12). Respaldada por SwiftData vía `@ModelActor`.
struct FavoritesClient: Sendable {
    var isFavorite: @Sendable (_ id: Int) async -> Bool
    /// Alterna el favorito y devuelve el nuevo estado (`true` = ahora favorito).
    var toggle: @Sendable (_ input: FavoriteInput) async -> Bool
    var all: @Sendable () async -> [FavoriteStationInfo]
}

// MARK: - SwiftData actor

@ModelActor
actor FavoritesStore {
    func isFavorite(_ id: Int) -> Bool {
        let descriptor = FetchDescriptor<FavoriteStation>(predicate: #Predicate { $0.id == id })
        return ((try? modelContext.fetchCount(descriptor)) ?? 0) > 0
    }

    func toggle(_ input: FavoriteInput) -> Bool {
        let id = input.id
        let descriptor = FetchDescriptor<FavoriteStation>(predicate: #Predicate { $0.id == id })
        let existing = (try? modelContext.fetch(descriptor)) ?? []

        if let favorite = existing.first {
            modelContext.delete(favorite)
            try? modelContext.save()
            return false
        }
        modelContext.insert(
            FavoriteStation(
                id: input.id,
                name: input.name,
                latitude: input.latitude,
                longitude: input.longitude,
                addedAt: Date()
            )
        )
        try? modelContext.save()
        return true
    }

    func all() -> [FavoriteStationInfo] {
        let descriptor = FetchDescriptor<FavoriteStation>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        let items = (try? modelContext.fetch(descriptor)) ?? []
        return items.map {
            FavoriteStationInfo(
                id: $0.id,
                name: $0.name,
                coordinate: Coordinate(latitude: $0.latitude, longitude: $0.longitude)
            )
        }
    }
}

// MARK: - Dependency

extension FavoritesClient: DependencyKey {
    static let liveValue: FavoritesClient = live(container: .fuelMapShared)
    static var previewValue: FavoritesClient { inMemory() }
    static var testValue: FavoritesClient { inMemory() }

    /// Cliente respaldado por un contenedor en memoria (tests/previews).
    static func inMemory() -> FavoritesClient {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        // En memoria, la creación no falla en la práctica.
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(for: FavoriteStation.self, configurations: configuration)
        return live(container: container)
    }

    private static func live(container: ModelContainer) -> FavoritesClient {
        let store = FavoritesStore(modelContainer: container)
        return FavoritesClient(
            isFavorite: { await store.isFavorite($0) },
            toggle: { await store.toggle($0) },
            all: { await store.all() }
        )
    }
}

extension DependencyValues {
    var favoritesClient: FavoritesClient {
        get { self[FavoritesClient.self] }
        set { self[FavoritesClient.self] = newValue }
    }
}

extension ModelContainer {
    /// Contenedor persistente compartido de la app. Si falla en disco, cae a memoria
    /// para no provocar un crash en arranque.
    static let fuelMapShared: ModelContainer = {
        do {
            return try ModelContainer(for: FavoriteStation.self)
        } catch {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            // swiftlint:disable:next force_try
            return try! ModelContainer(for: FavoriteStation.self, configurations: configuration)
        }
    }()
}
