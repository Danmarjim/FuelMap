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
            span: MKCoordinateSpan(latitudeDelta: MapDefaults.span, longitudeDelta: MapDefaults.span)
        )
    )
    @State private var showingList = false
    @State private var showingFavorites = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

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
                locationSearchButton
                settingsButton
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
        // Oculta mapa+controles+filtros a VoiceOver mientras el overlay bloqueante
        // está presente: un `.overlay` por sí solo tapa píxeles y toques, pero no el
        // árbol de accesibilidad (review RELEASE-001 F1-F2, C-3). Va antes del propio
        // `.overlay` de abajo para no ocultar también la tarjeta.
        .accessibilityHidden(store.locationPermissionDenied)
        .overlay {
            // Sin ningún contexto de ubicación (ni permiso ni ciudad buscada), el mapa
            // muestra Roma sin relación con el usuario: bloquea mapa, controles Y la
            // barra de filtros (ajustar combustible/radio no tiene sentido si no se ve
            // nada en pantalla) hasta que elija una de las dos salidas
            // (LOCATION-FALLBACK-001 parte 3). Va DESPUÉS de `.safeAreaInset` a
            // propósito: así cubre también la `FiltersView` del inset inferior.
            if store.locationPermissionDenied {
                LocationPromptOverlay(
                    onEnableLocation: { store.send(.openLocationSettingsTapped) },
                    onSearchCity: { store.send(.locationSearchButtonTapped) }
                )
            }
        }
        .sheet(item: $store.scope(state: \.detail, action: \.detail)) { detailStore in
            StationDetailView(store: detailStore)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingList) {
            StationListView(
                stations: store.sortedStations,
                origin: store.distanceOrigin,
                cheapestStationID: store.cheapestStationID,
                tiers: store.priceTiers,
                isLoading: store.isLoading,
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
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: Binding(
            get: { store.isShowingLocationSearch },
            set: { if !$0 { store.send(.locationSearchDismissed) } }
        )) {
            LocationSearchView(
                isSearching: store.isSearchingLocation,
                errorMessage: store.locationSearchError,
                onSubmit: { query in store.send(.locationSearchSubmitted(query)) },
                onClose: { store.send(.locationSearchDismissed) }
            )
            // `[.medium, .large]`, no solo `.medium`: con el teclado levantado (la
            // vista se autoenfoca en `onAppear`) el detent medium tapaba el botón
            // "Cerca" en iPhone SE/13 mini (review RELEASE-001 F1-F2, M-3).
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingFavorites) {
            FavoritesView(
                favorites: store.favoriteDisplays,
                tiers: store.favoritePriceTiers,
                cheapestID: store.cheapestFavoriteID,
                fuel: store.filters.fuel,
                isLoadingPrices: store.isLoadingFavoritePrices,
                onSelect: { favorite in
                    showingFavorites = false
                    store.send(.favoriteSelected(favorite))
                },
                onClose: { showingFavorites = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear { store.send(.onAppear) }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            store.send(.appBecameActive)
        }
        .onChange(of: store.recenter) { _, target in
            guard let target else { return }
            let region = MKCoordinateRegion(
                center: target.clLocationCoordinate,
                span: MKCoordinateSpan(latitudeDelta: store.span, longitudeDelta: store.span)
            )
            if reduceMotion {
                camera = .region(region)
            } else {
                withAnimation { camera = .region(region) }
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

    private var locationSearchButton: some View {
        Button {
            store.send(.locationSearchButtonTapped)
        } label: {
            Image(systemName: "magnifyingglass").font(.fmHeadline).mapControlChrome()
        }
        .accessibilityLabel("Cerca una città")
    }

    private var settingsButton: some View {
        Button {
            store.send(.delegate(.settingsTapped))
        } label: {
            Image(systemName: "info.circle").font(.fmHeadline).mapControlChrome()
        }
        .accessibilityLabel("Informazioni")
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
        .elevation(.e2, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
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
            .elevation(.e2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
