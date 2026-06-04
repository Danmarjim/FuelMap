//
//  StationListView.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import SwiftUI

/// Lista de estaciones del radio actual, ordenable por precio o distancia (FM-10).
/// Vista de presentación pura de datos del mapa (sin reducer propio).
struct StationListView: View {
    let stations: [Station]
    let center: Coordinate
    let cheapestStationID: Int?
    @Binding var sort: StationSort
    let onSelect: (Station) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Picker("Ordina per", selection: $sort) {
                    ForEach(StationSort.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)

                ForEach(stations) { station in
                    Button { onSelect(station) } label: { row(station) }
                        .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Distributori")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Chiudi") { onClose() }
                }
            }
            .overlay {
                if stations.isEmpty {
                    ContentUnavailableView("Nessun distributore", systemImage: "mappin.slash")
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ station: Station) -> some View {
        HStack(spacing: 12) {
            Image(systemName: station.id == cheapestStationID ? "fuelpump.fill" : "fuelpump")
                .foregroundStyle(station.id == cheapestStationID ? .green : .blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(station.name).fontWeight(.medium)
                Text(distanceText(to: station)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let price = station.cheapest?.price {
                Text("\(price.formatted(.number.precision(.fractionLength(3)))) €")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(station.id == cheapestStationID ? .green : .primary)
            }
        }
        .padding(.vertical, 2)
    }

    private func distanceText(to station: Station) -> String {
        let meters = center.distance(to: station.coordinate)
        if meters < 1000 {
            return "\(Int(meters.rounded())) m"
        }
        return "\((meters / 1000).formatted(.number.precision(.fractionLength(1)))) km"
    }
}

#Preview {
    StationListView(
        stations: StationFixtures.all,
        center: .italyDefault,
        cheapestStationID: 4,
        sort: .constant(.price),
        onSelect: { _ in },
        onClose: {}
    )
}
