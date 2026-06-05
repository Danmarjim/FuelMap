//
//  FavoritesView.swift
//  FuelMap
//
//  Created on 05/06/2026.
//

import SwiftUI

/// Lista de estaciones favoritas (FM-12). Tap → recentrar el mapa.
struct FavoritesView: View {
    let favorites: [FavoriteStationInfo]
    let onSelect: (FavoriteStationInfo) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            List(favorites) { favorite in
                Button { onSelect(favorite) } label: {
                    Label(favorite.name, systemImage: "star.fill")
                        .foregroundStyle(.primary)
                        .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(favorite.name))
                .accessibilityHint(Text("Centra la mappa qui"))
            }
            .listStyle(.plain)
            .navigationTitle("Preferiti")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Chiudi") { onClose() }
                }
            }
            .overlay {
                if favorites.isEmpty {
                    ContentUnavailableView("Nessun preferito", systemImage: "star.slash")
                }
            }
        }
    }
}

#Preview {
    FavoritesView(
        favorites: [
            FavoriteStationInfo(id: 1, name: "Eni Roma Centro", coordinate: .italyDefault)
        ],
        onSelect: { _ in },
        onClose: {}
    )
}
