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
    }

    enum Action: Equatable {
        case onAppear
        case locationResponse(Coordinate?)
        case mapCameraChanged(center: Coordinate)
        case stationsResponse(Result<[Station], APIError>)
        case stationTapped(Station)
        case detail(PresentationAction<StationDetailFeature.Action>)
        case filters(FiltersFeature.Action)
        case reload
    }

    @Dependency(\.apiClient) var apiClient
    @Dependency(\.locationClient) var locationClient
    @Dependency(\.continuousClock) var clock

    private enum CancelID { case reload }

    var body: some ReducerOf<Self> {
        Scope(state: \.filters, action: \.filters) {
            FiltersFeature()
        }
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.didRequestLocation else { return .none }
                state.didRequestLocation = true
                return .run { send in
                    let status = await locationClient.requestWhenInUse()
                    switch status {
                    case .authorizedWhenInUse, .authorizedAlways:
                        await send(.locationResponse(try? await locationClient.currentLocation()))
                    default:
                        await send(.locationResponse(nil))
                    }
                }

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

            case .reload:
                return load(&state)

            case let .stationsResponse(.success(stations)):
                state.isLoading = false
                state.errorMessage = nil
                state.stations = stations
                return .none

            case let .stationsResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.userMessage
                return .none

            case let .stationTapped(station):
                state.detail = StationDetailFeature.State(stationId: station.id, station: station)
                return .none

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

private extension APIError {
    /// Mensaje localizado (base italiano) para mostrar al usuario. l10n completa en FM-13.
    var userMessage: String {
        switch self {
        case .noResults:
            return "Nessun distributore trovato in zona."
        case .unauthorized:
            return "Accesso non autorizzato."
        case .network, .server, .decoding:
            return "Errore di connessione. Riprova."
        }
    }
}
