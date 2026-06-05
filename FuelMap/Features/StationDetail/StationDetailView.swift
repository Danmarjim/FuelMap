//
//  StationDetailView.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import ComposableArchitecture
import SwiftUI

/// Detalle de estación presentado en sheet (RFC §6.2).
struct StationDetailView: View {
    let store: StoreOf<StationDetailFeature>

    var body: some View {
        NavigationStack {
            Group {
                if let station = store.station {
                    content(for: station)
                } else if store.isLoading {
                    ProgressView("Caricamento…")
                } else if let error = store.errorMessage {
                    ContentUnavailableView("Errore", systemImage: "exclamationmark.triangle", description: Text(error))
                }
            }
            .navigationTitle(store.station?.name ?? String(localized: "Distributore"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        store.send(.favoriteToggled)
                    } label: {
                        Image(systemName: store.isFavorite ? "star.fill" : "star")
                    }
                    .accessibilityLabel(
                        store.isFavorite
                            ? Text("Rimuovi dai preferiti")
                            : Text("Aggiungi ai preferiti")
                    )
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Chiudi") { store.send(.closeTapped) }
                }
            }
            .onAppear { store.send(.onAppear) }
        }
    }

    @ViewBuilder
    private func content(for station: Station) -> some View {
        List {
            Section {
                pricesContent(for: station)
            } header: {
                Text("Prezzi")
            } footer: {
                if let updated = latestUpdate(for: station) {
                    Text("Aggiornato il \(updated.formatted(date: .abbreviated, time: .shortened))")
                }
            }

            Section {
                if let address = station.address {
                    Label(address, systemImage: "mappin.and.ellipse")
                }
                if let brand = station.brand {
                    Label(brand, systemImage: "building.2")
                }
                Button {
                    store.send(.directionsTapped)
                } label: {
                    Label("Indicazioni", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                }
            }
        }
    }

    @ViewBuilder
    private func pricesContent(for station: Station) -> some View {
        let groups = fuelGroups(for: station)
        if groups.isEmpty {
            Text("Nessun prezzo disponibile")
                .foregroundStyle(.secondary)
        } else {
            ForEach(groups, id: \.fuel) { group in
                fuelRow(group)
            }
        }
    }

    @ViewBuilder
    private func fuelRow(_ group: FuelGroup) -> some View {
        HStack {
            Text(group.fuel.label)
                .fontWeight(.medium)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let selfPrice = group.selfPrice {
                    priceLabel("Self", selfPrice.price)
                }
                if let servito = group.servito {
                    priceLabel("Servito", servito.price)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func priceLabel(_ kind: LocalizedStringKey, _ price: Decimal) -> some View {
        // Adapta a VStack si en horizontal no cabe (Dynamic Type grande).
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { priceLabelContent(kind, price) }
            VStack(alignment: .trailing, spacing: 0) { priceLabelContent(kind, price) }
        }
    }

    @ViewBuilder
    private func priceLabelContent(_ kind: LocalizedStringKey, _ price: Decimal) -> some View {
        Text(kind)
            .font(.caption2)
            .foregroundStyle(.secondary)
        Text(price.fuelPriceLabel)
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
    }

    // MARK: - Data shaping

    private struct FuelGroup {
        let fuel: FuelType
        let selfPrice: FuelPrice?
        let servito: FuelPrice?
    }

    private func fuelGroups(for station: Station) -> [FuelGroup] {
        FuelType.allCases.compactMap { fuel in
            let prices = station.prices.filter { $0.fuel == fuel }
            guard !prices.isEmpty else { return nil }
            return FuelGroup(
                fuel: fuel,
                selfPrice: prices.first { $0.isSelf },
                servito: prices.first { !$0.isSelf }
            )
        }
    }

    private func latestUpdate(for station: Station) -> Date? {
        station.prices.compactMap(\.communicatedAt).max()
    }
}

#Preview {
    StationDetailView(
        store: Store(
            initialState: StationDetailFeature.State(
                stationId: 1,
                station: StationFixtures.all[0]
            )
        ) {
            StationDetailFeature()
        }
    )
}
