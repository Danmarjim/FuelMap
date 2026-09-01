//
//  MapFeature+LocationSearch.swift
//  FuelMap
//
//  Created on 01/09/2026.
//

import ComposableArchitecture

/// Búsqueda manual de ciudad/dirección. Extraído del reducer principal
/// (`type_body_length`, mismo motivo que `MapFeature+Loading.swift`).
extension MapFeature {
    func searchLocation(_ state: inout State, query: String) -> Effect<Action> {
        // Mismo criterio de "vacío" que el resto del código (`nilIfEmpty`): antes la
        // vista recortaba con `.whitespaces` y el reducer con `.whitespacesAndNewlines`,
        // así que un texto pegado con solo un salto de línea pasaba el `.disabled` de
        // la vista y llegaba aquí para no hacer nada, dejando la hoja sin spinner ni
        // error (review RELEASE-001 F1-F2, M-7).
        guard let trimmed = query.nilIfEmpty else { return .none }
        state.isSearchingLocation = true
        state.locationSearchError = nil
        return .run { send in
            do {
                let coordinate = try await geocodingClient.search(trimmed)
                await send(.locationSearchResponse(.success(coordinate)))
            } catch let error as GeocodingError {
                await send(.locationSearchResponse(.failure(error)))
            } catch {
                await send(.locationSearchResponse(.failure(.network)))
            }
        }
        .cancellable(id: CancelID.locationSearch, cancelInFlight: true)
    }

    func handleLocationSearchResponse(
        _ state: inout State,
        result: Result<Coordinate, GeocodingError>
    ) -> Effect<Action> {
        state.isSearchingLocation = false
        switch result {
        case let .success(coordinate):
            state.center = coordinate
            state.recenter = coordinate
            // Ya no tiene sentido seguir explicando "mostrando Roma": el usuario acaba
            // de elegir dónde mirar a propósito.
            state.locationPermissionDenied = false
            state.isShowingLocationSearch = false
            return load(&state)

        case let .failure(error):
            state.locationSearchError = error.userMessage
            return .none
        }
    }
}
