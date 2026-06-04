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
            center: Coordinate.italyDefault.clCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )
    @State private var showingList = false

    var body: some View {
        Map(position: $camera) {
            UserAnnotation()
            ForEach(store.stations) { station in
                Annotation("", coordinate: station.coordinate.clCoordinate) {
                    StationPin(
                        name: station.name,
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
            let center = context.region.center
            store.send(.mapCameraChanged(
                center: Coordinate(latitude: center.latitude, longitude: center.longitude)
            ))
        }
        .overlay(alignment: .topLeading) { listButton }
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
        .onAppear { store.send(.onAppear) }
        .onChange(of: store.recenter) { _, target in
            guard let target else { return }
            withAnimation {
                camera = .region(
                    MKCoordinateRegion(
                        center: target.clCoordinate,
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
        .padding(.leading, 12)
        .padding(.top, 6)
        .accessibilityLabel("Elenco distributori")
    }

    @ViewBuilder
    private var statusBar: some View {
        if store.isLoading {
            Label("Caricamento…", systemImage: "arrow.triangle.2.circlepath")
                .font(.footnote)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 6)
        } else if let error = store.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 6)
        } else if store.stations.isEmpty {
            Label("Nessun distributore in zona", systemImage: "mappin.slash")
                .font(.footnote)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 6)
        }
    }
}

// MARK: - Helpers

private extension Coordinate {
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

#Preview {
    MapView(
        store: Store(initialState: MapFeature.State()) {
            MapFeature()
        }
    )
}
