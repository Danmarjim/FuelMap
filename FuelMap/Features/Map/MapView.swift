//
//  MapView.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import ComposableArchitecture
import MapKit
import SwiftUI

/// Mapa con gasolineras y precios (RFC §6.2).
struct MapView: View {
    @Bindable var store: StoreOf<MapFeature>

    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: Coordinate.italyDefault.clLocationCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )
    @State private var showingList = false
    @State private var showingFavorites = false

    var body: some View {
        Map(position: $camera) {
            UserAnnotation()
            ForEach(store.stations) { station in
                Annotation("", coordinate: station.coordinate.clLocationCoordinate) {
                    StationPin(
                        name: station.name,
                        fuel: store.filters.fuel,
                        price: station.cheapest?.price,
                        isCheapest: station.id == store.cheapestStationID
                    )
                    .onTapGesture { store.send(.stationTapped(station)) }
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            store.send(.mapCameraChanged(center: Coordinate(context.region.center)))
        }
        .overlay(alignment: .topLeading) {
            VStack(spacing: 8) {
                listButton
                favoritesButton
            }
            .padding(.leading, 12)
            .padding(.top, 6)
        }
        .safeAreaInset(edge: .top) { statusBar }
        .safeAreaInset(edge: .bottom) {
            FiltersView(store: store.scope(state: \.filters, action: \.filters))
        }
        .sheet(item: $store.scope(state: \.detail, action: \.detail)) { detailStore in
            StationDetailView(store: detailStore)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingList) {
            StationListView(
                stations: store.sortedStations,
                center: store.center,
                cheapestStationID: store.cheapestStationID,
                sort: Binding(
                    get: { store.sortOrder },
                    set: { store.send(.sortOrderChanged($0)) }
                ),
                onSelect: { station in
                    showingList = false
                    store.send(.recenterOnStation(station))
                },
                onClose: { showingList = false }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingFavorites) {
            FavoritesView(
                favorites: store.favorites,
                onSelect: { favorite in
                    showingFavorites = false
                    store.send(.favoriteSelected(favorite))
                },
                onClose: { showingFavorites = false }
            )
            .presentationDetents([.medium, .large])
        }
        .onAppear { store.send(.onAppear) }
        .onChange(of: store.recenter) { _, target in
            guard let target else { return }
            withAnimation {
                camera = .region(
                    MKCoordinateRegion(
                        center: target.clLocationCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: store.span, longitudeDelta: store.span)
                    )
                )
            }
        }
    }

    private var listButton: some View {
        Button {
            showingList = true
        } label: {
            Image(systemName: "list.bullet")
                .font(.headline)
                .padding(10)
                .background(.regularMaterial, in: Circle())
        }
        .accessibilityLabel("Elenco distributori")
    }

    private var favoritesButton: some View {
        Button {
            showingFavorites = true
        } label: {
            Image(systemName: "star")
                .font(.headline)
                .padding(10)
                .background(.regularMaterial, in: Circle())
        }
        .accessibilityLabel("Preferiti")
    }

    @ViewBuilder
    private var statusBar: some View {
        if store.isLoading {
            banner(Text("Caricamento…"), systemImage: "arrow.triangle.2.circlepath")
        } else if let error = store.errorMessage {
            banner(Text(error), systemImage: "exclamationmark.triangle.fill")
        } else if store.stations.isEmpty {
            banner(Text("Nessun distributore in zona"), systemImage: "mappin.slash")
        }
    }

    private func banner(_ title: Text, systemImage: String) -> some View {
        Label { title } icon: { Image(systemName: systemImage) }
            .font(.footnote)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
            .padding(.top, 6)
    }
}

#Preview {
    MapView(
        store: Store(initialState: MapFeature.State()) {
            MapFeature()
        }
    )
}
