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
        /// Estación más barata del conjunto actual (para destacarla en el mapa).
        var cheapestStationID: Int?
        var favorites: [FavoriteStationInfo] = []

        /// Estaciones ordenadas según `sortOrder` (para la lista).
        var sortedStations: [Station] {
            switch sortOrder {
            case .price:
                return stations.sorted {
                    ($0.cheapest?.price ?? .greatestFiniteMagnitude)
                        < ($1.cheapest?.price ?? .greatestFiniteMagnitude)
                }
            case .distance:
                return stations.sorted {
                    center.distance(to: $0.coordinate) < center.distance(to: $1.coordinate)
                }
            }
        }
    }

    enum Action: Equatable {
        case onAppear
        case locationResponse(Coordinate?)
        case mapCameraChanged(center: Coordinate)
        case stationsResponse(Result<[Station], APIError>)
        case stationTapped(Station)
        case detail(PresentationAction<StationDetailFeature.Action>)
        case filters(FiltersFeature.Action)
        case sortOrderChanged(StationSort)
        case recenterOnStation(Station)
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
                    state.recenter = coordinate
                }
                return load(&state)

            case let .mapCameraChanged(center):
                // Ignora micro-movimientos de cámara (jitter): evita reiniciar el
                // debounce sin cesar (que dejaría isLoading pegado) y consultas inútiles.
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

            case let .recenterOnStation(station):
                state.recenter = station.coordinate
                return .none

            case .loadFavorites:
                return .run { send in
                    await send(.favoritesResponse(favoritesClient.all()))
                }

            case let .favoritesResponse(favorites):
                state.favorites = favorites
                return .none

            case let .favoriteSelected(favorite):
                state.recenter = favorite.coordinate
                return .none

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
                state.errorMessage = error.userMessage
                return .none

            case let .stationTapped(station):
                state.detail = StationDetailFeature.State(stationId: station.id, station: station)
                return .none

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

extension Coordinate {
    /// Centro por defecto (Roma) cuando no hay ubicación del usuario.
    static let italyDefault = Coordinate(latitude: 41.9028, longitude: 12.4964)
}

/// Criterio de orden de la lista de estaciones (RFC §4 FM-10).
enum StationSort: String, CaseIterable, Sendable, Equatable {
    case price
    case distance

    var label: String {
        switch self {
        case .price: return "Prezzo"
        case .distance: return "Distanza"
        }
    }
}

private extension APIError {
    /// Mensaje localizado (it/es/en) para mostrar al usuario.
    var userMessage: String {
        switch self {
        case .noResults:
            return String(localized: "Nessun distributore trovato in zona.")
        case .unauthorized:
            return String(localized: "Accesso non autorizzato.")
        case .network, .server, .decoding:
            return String(localized: "Errore di connessione. Riprova.")
        }
    }
}
