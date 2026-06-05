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

        var id: Int { stationId }
    }

    enum Action: Equatable {
        case onAppear
        case stationResponse(Result<Station, APIError>)
        case directionsTapped
        case closeTapped
    }

    @Dependency(\.apiClient) var apiClient
    @Dependency(\.openURL) var openURL
    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                let id = state.stationId
                return .run { send in
                    do {
                        let station = try await apiClient.stationDetail(id)
                        await send(.stationResponse(.success(station)))
                    } catch let error as APIError {
                        await send(.stationResponse(.failure(error)))
                    } catch {
                        await send(.stationResponse(.failure(.network(error.localizedDescription))))
                    }
                }

            case let .stationResponse(.success(station)):
                state.isLoading = false
                state.errorMessage = nil
                state.station = station
                return .none

            case let .stationResponse(.failure(error)):
                state.isLoading = false
                // Si ya teníamos datos del pin, los conservamos; si no, mostramos error.
                if state.station == nil {
                    state.errorMessage = error.userMessage
                }
                return .none

            case .directionsTapped:
                guard let coordinate = state.station?.coordinate else { return .none }
                let destination = "\(coordinate.latitude),\(coordinate.longitude)"
                guard let url = URL(string: "http://maps.apple.com/?daddr=\(destination)") else {
                    return .none
                }
                return .run { _ in await openURL(url) }

            case .closeTapped:
                return .run { _ in await dismiss() }
            }
        }
    }
}

private extension APIError {
    var userMessage: String {
        switch self {
        case .noResults:
            return String(localized: "Distributore non trovato.")
        case .unauthorized:
            return String(localized: "Accesso non autorizzato.")
        case .network, .server, .decoding:
            return String(localized: "Errore di connessione. Riprova.")
        }
    }
}
