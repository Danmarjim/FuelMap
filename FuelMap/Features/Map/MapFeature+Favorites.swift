//
//  MapFeature+Favorites.swift
//  FuelMap
//
//  Created on 17/07/2026.
//

import ComposableArchitecture
import Foundation

// MARK: - Favoritos enriquecidos (derivados del estado)

extension MapFeature.State {
    /// Favoritos enriquecidos con su precio en vivo, ordenados por precio ascendente
    /// (los que tienen precio primero; los no disponibles al final, en su orden original).
    var favoriteDisplays: [FavoriteDisplay] {
        let byID = Dictionary(favoriteStations.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let origin = distanceOrigin
        return favorites
            .enumerated()
            .map { index, info in
                FavoriteDisplay(
                    info: info,
                    station: byID[info.id],
                    distance: origin.distance(to: info.coordinate),
                    order: index
                )
            }
            .sorted { lhs, rhs in
                switch (lhs.price, rhs.price) {
                case let (lhsPrice?, rhsPrice?):
                    return lhsPrice == rhsPrice ? closer(lhs, rhs) : lhsPrice < rhsPrice
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return closer(lhs, rhs)
                }
            }
    }

    /// Desempate a igualdad de precio: manda la más cercana ("¿a cuál voy ahora?").
    /// `order` (orden de alta) cierra el empate exacto para que el orden sea estable.
    private func closer(_ lhs: FavoriteDisplay, _ rhs: FavoriteDisplay) -> Bool {
        lhs.distance == rhs.distance ? lhs.order < rhs.order : lhs.distance < rhs.distance
    }

    /// Favorito más barato (para el `BestFlag` en la hoja de favoritos).
    var cheapestFavoriteID: Int? {
        favoriteStations.min {
            ($0.cheapest?.price ?? .greatestFiniteMagnitude)
                < ($1.cheapest?.price ?? .greatestFiniteMagnitude)
        }?.id
    }

    /// Terciles de precio del conjunto de favoritos (para sus `TierTag`).
    var favoritePriceTiers: PriceTiers {
        PriceTiers(prices: favoriteStations.compactMap { $0.cheapest?.price })
    }
}

// MARK: - FavoriteDisplay

/// Favorito enriquecido con su precio en vivo para el combustible activo.
/// `station` es `nil` si ese favorito no vende el combustible filtrado (→ "non disp.").
struct FavoriteDisplay: Equatable, Identifiable, Sendable {
    let info: FavoriteStationInfo
    let station: Station?
    /// Metros desde `distanceOrigin` (ubicación del usuario o centro del mapa).
    let distance: Double
    /// Posición original (addedAt) para desempatar el orden.
    let order: Int

    var id: Int { info.id }
    var price: Decimal? { station?.cheapest?.price }
}
