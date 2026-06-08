//
//  StationListView.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import SwiftUI

/// Lista de estaciones del radio actual, ordenable por precio o distancia (FM-10).
/// Vista de presentación pura (sin reducer propio), reestilizada al design system (R4).
struct StationListView: View {
    let stations: [Station]
    /// Referencia para la distancia (ubicación del usuario; si no, centro del mapa).
    let origin: Coordinate
    let cheapestStationID: Int?
    /// Terciles de precio del conjunto, calculados en el store (no recomputar aquí).
    let tiers: PriceTiers
    var isLoading: Bool = false
    @Binding var sort: StationSort
    let onSelect: (Station) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Stazioni vicine", count: stations.isEmpty ? nil : stations.count, onClose: onClose)
            sortBar
            if isLoading && stations.isEmpty {
                SkeletonList()
                Spacer()
            } else if stations.isEmpty {
                Spacer()
                SheetEmptyState(
                    systemImage: "mappin.slash",
                    title: "Nessun distributore",
                    message: "Nessun distributore in zona. Allarga il raggio o sposta la mappa."
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(stations.enumerated()), id: \.element.id) { index, station in
                            if index > 0 { separator }
                            rowButton(station)
                        }
                    }
                }
            }
        }
        .background(Color(.surfaceElevated))
    }

    private var sortBar: some View {
        HStack(spacing: Spacing.s3) {
            SortPill(option: .price, isActive: sort == .price) { sort = .price }
            SortPill(option: .distance, isActive: sort == .distance) { sort = .distance }
            Spacer()
        }
        .padding(.horizontal, Spacing.s5)
        .padding(.bottom, Spacing.s3)
    }

    private var separator: some View {
        Rectangle().fill(Color(.separator)).frame(height: 1).padding(.leading, 60)
    }

    private func rowButton(_ station: Station) -> some View {
        Button { onSelect(station) } label: {
            StationRow(
                brand: BrandStyle.from(station.brand),
                name: station.name,
                distance: distanceText(to: station),
                price: station.cheapest?.price,
                tier: tiers.tier(for: station.cheapest?.price),
                isCheapest: station.id == cheapestStationID
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(voiceOverLabel(for: station)))
        .accessibilityHint(Text("Centra la mappa qui"))
    }

    private func distanceText(to station: Station) -> String {
        let meters = origin.distance(to: station.coordinate)
        if meters < 1000 {
            return "\(Int(meters.rounded())) m"
        }
        return "\((meters / 1000).formatted(.number.precision(.fractionLength(1)))) km"
    }

    private func voiceOverLabel(for station: Station) -> String {
        var parts = [station.name, distanceText(to: station)]
        if let price = station.cheapest?.price { parts.append(price.fuelPriceLabel) }
        parts.append(tiers.tier(for: station.cheapest?.price).label)
        if station.id == cheapestStationID { parts.append(String(localized: "il più economico")) }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    StationListView(
        stations: StationFixtures.all,
        origin: .italyDefault,
        cheapestStationID: 4,
        tiers: PriceTiers(prices: StationFixtures.all.compactMap { $0.cheapest?.price }),
        sort: .constant(.price),
        onSelect: { _ in },
        onClose: {}
    )
}
