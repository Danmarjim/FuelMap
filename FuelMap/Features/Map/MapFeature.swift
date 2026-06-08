//
//  MapFeature.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import ComposableArchitecture

/// Feature principal: mapa con gasolineras y precios (RFC §6.2).
@Reducer
struct MapFeature {
    @ObservableState
    struct State: Equatable {
        /// Centro actual del mapa (usado para consultar la API).
        var center: Coordinate = .italyDefault
        /// Ubicación del usuario (referencia para distancias). Fijada al arrancar.
        var userLocation: Coordinate?
        /// Apertura del mapa (latitudeDelta) para el zoom de la cámara.
        var span: Double = 0.08
        var filters = FiltersFeature.State()
        var stations: [Station] = []
        var isLoading = false
        @Presents var detail: StationDetailFeature.State?
        var errorMessage: String?
        /// Objetivo de recentrado one-shot (p. ej. ubicación del usuario al arrancar).
        var recenter: Coordinate?
        var didRequestLocation = false
        var sortOrder: StationSort = .price
        /// Tipo de mapa (estándar / híbrido / satélite) — control de capas.
        var mapStyle: MapStyleOption = .standard
        /// Estación más barata del conjunto actual (para destacarla en el mapa).
        var cheapestStationID: Int?
        var favorites: [FavoriteStationInfo] = []

        /// Elementos del mapa: estaciones individuales o clusters según el zoom (FM-15).
        var mapItems: [MapItem] {
            MapClustering.items(stations: stations, span: span)
        }

        /// Umbrales de color de precio (terciles) del set actual (FM-18).
        var priceTiers: PriceTiers {
            PriceTiers(prices: stations.compactMap { $0.cheapest?.price })
        }

        /// Origen para calcular distancias: la ubicación del usuario; si no hay, el centro.
        var distanceOrigin: Coordinate { userLocation ?? center }

        /// Estaciones ordenadas según `sortOrder` (para la lista).
        var sortedStations: [Station] {
            switch sortOrder {
            case .price:
                return stations.sorted {
                    ($0.cheapest?.price ?? .greatestFiniteMagnitude)
                        < ($1.cheapest?.price ?? .greatestFiniteMagnitude)
                }
            case .distance:
                let origin = distanceOrigin
                return stations.sorted {
                    origin.distance(to: $0.coordinate) < origin.distance(to: $1.coordinate)
                }
            }
        }
    }

    enum Action: Equatable {
        case onAppear
        case locationResponse(Coordinate?)
        case mapCameraChanged(center: Coordinate, span: Double)
        case stationsResponse(Result<[Station], APIError>)
        case stationTapped(Station)
        case stationSelectedFromList(Station)
        case detail(PresentationAction<StationDetailFeature.Action>)
        case filters(FiltersFeature.Action)
        case sortOrderChanged(StationSort)
        case mapStyleChanged(MapStyleOption)
        case recenterOnStation(Station)
        case clusterTapped(StationCluster)
        case recenterHandled
        case loadFavorites
        case favoritesResponse([FavoriteStationInfo])
        case favoriteSelected(FavoriteStationInfo)
        case reload
    }

    @Dependency(\.apiClient) var apiClient
    @Dependency(\.locationClient) var locationClient
    @Dependency(\.favoritesClient) var favoritesClient
    @Dependency(\.continuousClock) var clock

    private enum CancelID { case reload }

    var body: some ReducerOf<Self> {
        Scope(state: \.filters, action: \.filters) {
            FiltersFeature()
        }
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.didRequestLocation else { return .send(.loadFavorites) }
                state.didRequestLocation = true
                return .merge(
                    .run { send in
                        let status = await locationClient.requestWhenInUse()
                        switch status {
                        case .authorizedWhenInUse, .authorizedAlways:
                            await send(.locationResponse(try? await locationClient.currentLocation()))
                        default:
                            await send(.locationResponse(nil))
                        }
                    },
                    .send(.loadFavorites)
                )

            case let .locationResponse(coordinate):
                if let coordinate {
                    state.center = coordinate
                    state.userLocation = coordinate
                    state.recenter = coordinate
                }
                return load(&state)

            case let .mapCameraChanged(center, span):
                // El span (zoom) se actualiza siempre para reclusterizar; el centro y la
                // recarga solo si el movimiento supera el epsilon (ignora el jitter, que
                // si no reiniciaría el debounce sin cesar dejando isLoading pegado).
                state.span = span
                let epsilon = 0.0005
                let moved = abs(center.latitude - state.center.latitude) > epsilon
                    || abs(center.longitude - state.center.longitude) > epsilon
                guard moved else { return .none }
                state.center = center
                return load(&state, debounced: true)

            case .filters:
                // Cualquier cambio de filtro (combustible/self/radio) recarga.
                return load(&state)

            case let .sortOrderChanged(order):
                state.sortOrder = order
                return .none

            case let .mapStyleChanged(style):
                state.mapStyle = style
                return .none

            case let .recenterOnStation(station):
                state.recenter = station.coordinate
                return .none

            case let .clusterTapped(cluster):
                // Acercar para desagrupar: reduce el span y recentra en el cluster.
                state.span = max(state.span / 3, 0.005)
                state.recenter = cluster.coordinate
                return .none

            case .recenterHandled:
                // La vista ya aplicó el recentrado; consumir el evento para que
                // reseleccionar el mismo destino vuelva a disparar (nil → coord).
                state.recenter = nil
                return .none

            case .loadFavorites:
                return .run { send in
                    await send(.favoritesResponse(favoritesClient.all()))
                }

            case let .favoritesResponse(favorites):
                state.favorites = favorites
                return .none

            case let .favoriteSelected(favorite):
                // Mismo patrón que la lista: recentra ya y abre el detalle tras cerrarse
                // el sheet de favoritos. Pre-rellena con lo que sabemos (nombre+coords);
                // el detalle carga el resto (todos los combustibles) vía station_detail.
                state.recenter = favorite.coordinate
                let station = Station(
                    id: favorite.id, name: favorite.name, brand: nil, address: nil,
                    municipality: nil, province: nil, coordinate: favorite.coordinate, prices: []
                )
                return .run { send in
                    try await clock.sleep(for: .milliseconds(350))
                    await send(.stationTapped(station))
                }

            case .reload:
                return load(&state)

            case let .stationsResponse(.success(stations)):
                state.isLoading = false
                state.errorMessage = nil
                state.stations = stations
                state.cheapestStationID = stations.min {
                    ($0.cheapest?.price ?? .greatestFiniteMagnitude)
                        < ($1.cheapest?.price ?? .greatestFiniteMagnitude)
                }?.id
                return .none

            case let .stationsResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.userMessage(
                    noResults: String(localized: "Nessun distributore trovato in zona.")
                )
                return .none

            case let .stationTapped(station):
                // Centra el mapa en el pin pulsado (mejor UX) y abre el detalle.
                state.recenter = station.coordinate
                state.detail = StationDetailFeature.State(
                    stationId: station.id,
                    station: station,
                    selectedFuel: state.filters.fuel
                )
                return .none

            case let .stationSelectedFromList(station):
                // Recentra ya; el detalle se abre tras cerrarse el sheet de la lista.
                state.recenter = station.coordinate
                return .run { send in
                    try await clock.sleep(for: .milliseconds(350))
                    await send(.stationTapped(station))
                }

            case .detail(.dismiss):
                // Al cerrar el detalle, refresca favoritos (pudo cambiar el toggle).
                return .send(.loadFavorites)

            case .detail:
                return .none
            }
        }
        .ifLet(\.$detail, action: \.detail) {
            StationDetailFeature()
        }
    }

    /// Lanza la consulta de estaciones, cancelando cualquier carga en vuelo.
    /// Con `debounced` espera ~400 ms (para no saturar al mover el mapa).
    private func load(_ state: inout State, debounced: Bool = false) -> Effect<Action> {
        state.isLoading = true
        let center = state.center
        let radius = state.filters.radiusKm
        let fuel = state.filters.fuel
        let selfOnly = state.filters.selfOnly
        return .run { send in
            if debounced {
                try await clock.sleep(for: .milliseconds(400))
            }
            do {
                let stations = try await apiClient.nearbyStations(center, radius, fuel, selfOnly)
                await send(.stationsResponse(.success(stations)))
            } catch let error as APIError {
                await send(.stationsResponse(.failure(error)))
            } catch {
                await send(.stationsResponse(.failure(.network(error.localizedDescription))))
            }
        }
        .cancellable(id: CancelID.reload, cancelInFlight: true)
    }
}

// MARK: - Helpers

/// Tipo de mapa para el control de capas (RESTYLE-001 R2).
enum MapStyleOption: String, CaseIterable, Sendable, Equatable {
    case standard
    case hybrid
    case imagery

    var label: String {
        switch self {
        case .standard: return String(localized: "Standard", comment: "Tipo de mapa: estándar")
        case .hybrid: return String(localized: "Ibrida", comment: "Tipo de mapa: híbrido")
        case .imagery: return String(localized: "Satellite", comment: "Tipo de mapa: satélite")
        }
    }

    var symbol: String {
        switch self {
        case .standard: return "map"
        case .hybrid: return "map.fill"
        case .imagery: return "globe.americas.fill"
        }
    }
}

/// Criterio de orden de la lista de estaciones (RFC §4 FM-10).
enum StationSort: String, CaseIterable, Sendable, Equatable {
    case price
    case distance

    var label: String {
        switch self {
        case .price: return String(localized: "Prezzo")
        case .distance: return String(localized: "Distanza")
        }
    }
}
