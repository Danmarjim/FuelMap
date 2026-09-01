//
//  MapFeature+Loading.swift
//  FuelMap
//
//  Created on 01/09/2026.
//

import ComposableArchitecture

/// Efectos de carga de `MapFeature` (estaciones cercanas + precios de favoritos).
/// Extraído del reducer principal (`type_body_length`, límite 250 — mismo motivo que
/// llevó a `MapFeature+Favorites.swift`).
extension MapFeature {
    /// Lanza la consulta de estaciones, cancelando cualquier carga en vuelo.
    /// Con `debounced` espera ~400 ms (para no saturar al mover el mapa).
    func load(_ state: inout State, debounced: Bool = false) -> Effect<Action> {
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

    /// Trae los precios en vivo de los favoritos para el combustible/self activos.
    /// Sin favoritos, limpia el estado y no hace red.
    func loadFavoritePrices(_ state: inout State) -> Effect<Action> {
        let ids = state.favorites.map(\.id)
        guard !ids.isEmpty else {
            state.favoriteStations = []
            state.isLoadingFavoritePrices = false
            return .none
        }
        state.isLoadingFavoritePrices = true
        let fuel = state.filters.fuel
        let selfOnly = state.filters.selfOnly
        return .run { send in
            do {
                let stations = try await apiClient.stationsByIDs(ids, fuel, selfOnly)
                await send(.favoritePricesResponse(.success(stations)))
            } catch let error as APIError {
                await send(.favoritePricesResponse(.failure(error)))
            } catch {
                await send(.favoritePricesResponse(.failure(.network(error.localizedDescription))))
            }
        }
        .cancellable(id: CancelID.favoritePrices, cancelInFlight: true)
    }
}
