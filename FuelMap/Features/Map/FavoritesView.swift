//
//  FavoritesView.swift
//  FuelMap
//
//  Created on 05/06/2026.
//

import SwiftUI

/// Lista de estaciones favoritas (FM-12). Tap → recentrar el mapa.
/// El modelo de favorito guarda solo nombre+coordenada; la marca se infiere del nombre
/// y no hay precio/distancia en vivo (mejora futura).
struct FavoritesView: View {
    let favorites: [FavoriteStationInfo]
    let onSelect: (FavoriteStationInfo) -> Void
    let onClose: () -> Void

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

    private func rowButton(_ favorite: FavoriteStationInfo) -> some View {
        Button { onSelect(favorite) } label: {
            StationRow(
                brand: BrandStyle.from(favorite.name),
                name: favorite.name,
                trailingStar: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(favorite.name))
        .accessibilityHint(Text("Centra la mappa qui"))
    }
}

#Preview {
    FavoritesView(
        favorites: [
            FavoriteStationInfo(id: 1, name: "Eni Roma Centro", coordinate: .italyDefault),
            FavoriteStationInfo(id: 2, name: "Q8 Termini", coordinate: .italyDefault)
        ],
        onSelect: { _ in },
        onClose: {}
    )
}
