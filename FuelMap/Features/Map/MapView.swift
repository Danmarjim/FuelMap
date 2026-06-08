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
            ForEach(store.mapItems) { item in
                annotation(for: item)
            }
        }
        .modifier(MapStyleModifier(option: store.mapStyle))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            store.send(.mapCameraChanged(
                center: Coordinate(context.region.center),
                span: context.region.span.latitudeDelta
            ))
        }
        .overlay(alignment: .topLeading) {
            VStack(spacing: Spacing.s3) {
                listButton
                favoritesButton
                layersButton
            }
            .padding(.leading, Spacing.s4)
            .padding(.top, Spacing.s2)
        }
        .overlay(alignment: .top) { statusBar }
        .safeAreaInset(edge: .bottom) {
            FiltersView(
                store: store.scope(state: \.filters, action: \.filters),
                sort: Binding(
                    get: { store.sortOrder },
                    set: { store.send(.sortOrderChanged($0)) }
                )
            )
        }
        .sheet(item: $store.scope(state: \.detail, action: \.detail)) { detailStore in
            StationDetailView(store: detailStore)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingList) {
            StationListView(
                stations: store.sortedStations,
                origin: store.distanceOrigin,
                cheapestStationID: store.cheapestStationID,
                sort: Binding(
                    get: { store.sortOrder },
                    set: { store.send(.sortOrderChanged($0)) }
                ),
                onSelect: { station in
                    showingList = false
                    store.send(.stationSelectedFromList(station))
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
            store.send(.recenterHandled)
        }
    }

    @MapContentBuilder
    private func annotation(for item: MapItem) -> some MapContent {
        switch item {
        case let .station(station):
            Annotation("", coordinate: station.coordinate.clLocationCoordinate) {
                StationPin(
                    name: station.name,
                    fuel: store.filters.fuel,
                    price: station.cheapest?.price,
                    brand: BrandStyle.from(station.brand),
                    tier: store.priceTiers.tier(for: station.cheapest?.price),
                    isCheapest: station.id == store.cheapestStationID,
                    isSelected: station.id == store.detail?.stationId
                )
                .onTapGesture { store.send(.stationTapped(station)) }
            }
        case let .cluster(cluster):
            Annotation("", coordinate: cluster.coordinate.clLocationCoordinate) {
                ClusterPin(
                    count: cluster.count,
                    cheapestPrice: cluster.cheapestPrice,
                    tier: store.priceTiers.tier(for: cluster.cheapestPrice)
                )
                .onTapGesture { store.send(.clusterTapped(cluster)) }
            }
        }
    }

    // MARK: - Controles flotantes

    private var listButton: some View {
        Button {
            showingList = true
        } label: {
            Image(systemName: "list.bullet").font(.fmHeadline).mapControlChrome()
        }
        .accessibilityLabel("Elenco distributori")
    }

    private var favoritesButton: some View {
        Button {
            showingFavorites = true
        } label: {
            Image(systemName: "star").font(.fmHeadline).mapControlChrome()
        }
        .accessibilityLabel("Preferiti")
    }

    private var layersButton: some View {
        Menu {
            Picker("Tipo di mappa", selection: Binding(
                get: { store.mapStyle },
                set: { store.send(.mapStyleChanged($0)) }
            )) {
                ForEach(MapStyleOption.allCases, id: \.self) { option in
                    Label(option.label, systemImage: option.symbol).tag(option)
                }
            }
        } label: {
            Image(systemName: store.mapStyle.symbol).font(.fmHeadline).mapControlChrome()
        }
        .accessibilityLabel("Tipo di mappa")
    }

    @ViewBuilder
    private var statusBar: some View {
        if store.isLoading {
            banner(Text("Caricamento…"), systemImage: "arrow.triangle.2.circlepath", kind: .loading)
        } else if let error = store.errorMessage {
            banner(Text(error), systemImage: "exclamationmark.triangle.fill", kind: .error)
        } else if store.stations.isEmpty {
            banner(Text("Nessun distributore in zona"), systemImage: "mappin.slash", kind: .info)
        }
    }

    private func banner(_ title: Text, systemImage: String, kind: BannerKind) -> some View {
        HStack(spacing: Spacing.s3) {
            Image(systemName: systemImage)
                .foregroundStyle(kind == .error ? Color(.error) : Color(.brandTint))
            title
                .font(.fmFootnote.weight(.semibold))
                .foregroundStyle(kind == .error ? Color(.error) : Color(.textPrimary))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s3)
        .background(
            kind == .error ? Color(.errorSurface) : Color(.surfaceElevated),
            in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
        )
        .elevation(.e2)
        .padding(.top, Spacing.s2)
    }
}

private enum BannerKind { case info, loading, error }

/// Aplica el `MapStyle` de MapKit según la opción de capas (tipos concretos distintos
/// por rama → se resuelve con un `ViewModifier`).
private struct MapStyleModifier: ViewModifier {
    let option: MapStyleOption

    @ViewBuilder
    func body(content: Content) -> some View {
        switch option {
        case .standard: content.mapStyle(.standard)
        case .hybrid: content.mapStyle(.hybrid)
        case .imagery: content.mapStyle(.imagery)
        }
    }
}

private extension View {
    /// Estilo de control flotante del mapa (44pt, `surfaceElevated`, `e2`, icono `brandTint`).
    func mapControlChrome() -> some View {
        self
            .foregroundStyle(Color(.brandTint))
            .frame(width: 44, height: 44)
            .background(Color(.surfaceElevated), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .elevation(.e2)
            .contentShape(Rectangle())
    }
}

#Preview {
    MapView(
        store: Store(initialState: MapFeature.State()) {
            MapFeature()
        }
    )
}
