//
//  FavoritesView.swift
//  FuelMap
//
//  Created on 05/06/2026.
//

import SwiftUI

/// Hoja de favoritos con **precio en vivo** del combustible activo (FM-12, FAV-PRICE).
/// Responde de un vistazo "¿a cuál voy ahora?": ordena por precio ascendente y marca
/// el más barato con `BestFlag`. Un favorito sin ese combustible muestra "non disp.".
/// Los precios llegan del store (`stations_by_ids`); la marca/coordenada del propio favorito.
struct FavoritesView: View {
    let favorites: [FavoriteDisplay]
    /// Terciles de precio del conjunto de favoritos (calculados en el store).
    let tiers: PriceTiers
    /// Favorito más barato → recibe el `BestFlag`.
    let cheapestID: Int?
    /// Combustible activo (para la nota "non disp." y VoiceOver).
    let fuel: FuelType
    var isLoadingPrices: Bool = false
    let onSelect: (FavoriteStationInfo) -> Void
    let onClose: () -> Void

    private var hasPrices: Bool { favorites.contains { $0.price != nil } }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Preferiti", count: favorites.isEmpty ? nil : favorites.count, onClose: onClose)
            if favorites.isEmpty {
                Spacer()
                SheetEmptyState(
                    systemImage: "star.slash",
                    title: "Nessun preferito",
                    message: "Aggiungi una stazione ai preferiti dal suo dettaglio."
                )
                Spacer()
            } else if isLoadingPrices && !hasPrices {
                // Primera carga de precios: skeleton (en refrescos conservamos los previos).
                SkeletonList(rows: min(favorites.count, 4))
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(favorites.enumerated()), id: \.element.id) { index, favorite in
                            if index > 0 { separator }
                            rowButton(favorite)
                        }
                    }
                }
            }
        }
        .background(Color(.surfaceElevated))
    }

    private var separator: some View {
        Rectangle().fill(Color(.separator)).frame(height: 1).padding(.leading, 60)
    }

    private func rowButton(_ favorite: FavoriteDisplay) -> some View {
        Button { onSelect(favorite.info) } label: {
            StationRow(
                brand: BrandStyle.from(favorite.station?.brand ?? favorite.info.name),
                name: favorite.info.name,
                distance: distanceText(favorite.distance),
                price: favorite.price,
                tier: favorite.price.map { tiers.tier(for: $0) },
                isCheapest: favorite.id == cheapestID,
                unavailableNote: favorite.station == nil ? "n/d" : nil
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(voiceOverLabel(for: favorite)))
        .accessibilityHint(Text("Centra la mappa qui"))
    }

    private func distanceText(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters.rounded())) m"
        }
        return "\((meters / 1000).formatted(.number.precision(.fractionLength(1)))) km"
    }

    private func voiceOverLabel(for favorite: FavoriteDisplay) -> String {
        var parts = [favorite.info.name, distanceText(favorite.distance)]
        if let price = favorite.price {
            parts.append(price.fuelPriceLabel)
            parts.append(tiers.tier(for: price).label)
            if favorite.id == cheapestID { parts.append(String(localized: "il più economico")) }
        } else {
            parts.append(String(localized: "Prezzo non disponibile per \(fuel.label)"))
        }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    let stations = Array(StationFixtures.all.prefix(3))
    let displays = stations.enumerated().map { index, station in
        FavoriteDisplay(
            info: FavoriteStationInfo(id: station.id, name: station.name, coordinate: station.coordinate),
            station: station.id == 3 ? nil : station,   // id 3 simula "non disp."
            distance: Coordinate.italyDefault.distance(to: station.coordinate),
            order: index
        )
    }
    return FavoritesView(
        favorites: displays,
        tiers: PriceTiers(prices: stations.compactMap { $0.cheapest?.price }),
        cheapestID: stations.min { ($0.cheapest?.price ?? 0) < ($1.cheapest?.price ?? 0) }?.id,
        fuel: .benzina,
        onSelect: { _ in },
        onClose: {}
    )
}
