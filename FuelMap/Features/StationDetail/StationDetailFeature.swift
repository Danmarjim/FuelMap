//
//  StationDetailFeature.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import ComposableArchitecture
import Foundation

/// Detalle de una estación: todos los combustibles + "cómo llegar" (RFC §6.2).
@Reducer
struct StationDetailFeature {
    @ObservableState
    struct State: Equatable, Identifiable {
        let stationId: Int
        /// Pre-rellenado desde el pin del mapa (un solo combustible); se refina al cargar.
        var station: Station?
        var isLoading = false
        var errorMessage: String?
        var isFavorite = false

        var id: Int { stationId }
    }

    enum Action: Equatable {
        case onAppear
        case stationResponse(Result<Station, APIError>)
        case favoriteStatus(Bool)
        case favoriteToggled
        case navigate(NavApp)
        case closeTapped
    }

    @Dependency(\.apiClient) var apiClient
    @Dependency(\.favoritesClient) var favoritesClient
    @Dependency(\.openURL) var openURL
    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                let id = state.stationId
                return .merge(
                    .run { send in
                        do {
                            let station = try await apiClient.stationDetail(id)
                            await send(.stationResponse(.success(station)))
                        } catch let error as APIError {
                            await send(.stationResponse(.failure(error)))
                        } catch {
                            await send(.stationResponse(.failure(.network(error.localizedDescription))))
                        }
                    },
                    .run { send in
                        await send(.favoriteStatus(favoritesClient.isFavorite(id)))
                    }
                )

            case let .stationResponse(.success(station)):
                state.isLoading = false
                state.errorMessage = nil
                state.station = station
                return .none

            case let .stationResponse(.failure(error)):
                state.isLoading = false
                // Si ya teníamos datos del pin, los conservamos; si no, mostramos error.
                if state.station == nil {
                    state.errorMessage = error.userMessage(
                        noResults: String(localized: "Distributore non trovato.")
                    )
                }
                return .none

            case let .favoriteStatus(isFavorite):
                state.isFavorite = isFavorite
                return .none

            case .favoriteToggled:
                guard let station = state.station else { return .none }
                let input = FavoriteInput(
                    id: station.id,
                    name: station.name,
                    latitude: station.coordinate.latitude,
                    longitude: station.coordinate.longitude
                )
                return .run { send in
                    await send(.favoriteStatus(favoritesClient.toggle(input)))
                }

            case let .navigate(app):
                guard let coordinate = state.station?.coordinate,
                      let url = app.directionsURL(to: coordinate) else { return .none }
                return .run { _ in await openURL(url) }

            case .closeTapped:
                return .run { _ in await dismiss() }
            }
        }
    }
}
