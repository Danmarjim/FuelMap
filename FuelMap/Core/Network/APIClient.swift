//
//  APIClient.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import ComposableArchitecture

/// Errores de la capa de red (RFC §3.2). Tipados — nunca `Error` crudo.
enum APIError: Error, Equatable, Sendable {
    case network(String)
    case decoding
    case unauthorized
    case server(Int)
    case noResults
}

extension APIError {
    /// Mensaje localizado (it/es/en) para mostrar al usuario.
    /// `noResults` varía según el contexto (mapa vs detalle).
    func userMessage(noResults: String) -> String {
        switch self {
        case .noResults:
            return noResults
        case .unauthorized:
            return String(localized: "Accesso non autorizzato.")
        case .network, .server, .decoding:
            return String(localized: "Errore di connessione. Riprova.")
        }
    }
}

/// Única puerta de la app hacia los datos (RFC §3.2).
///
/// `liveValue` = Supabase real (`APIClient+Live`); `previewValue` = mock (fixtures);
/// `testValue` = unimplemented. El contrato no cambia entre ellos.
struct APIClient: Sendable {
    /// Estaciones con el combustible dado dentro de `radiusKm` del punto, ordenadas por precio.
    var nearbyStations: @Sendable (
        _ center: Coordinate,
        _ radiusKm: Double,
        _ fuel: FuelType,
        _ selfOnly: Bool
    ) async throws -> [Station]

    /// Detalle completo (todos los combustibles) de una estación.
    var stationDetail: @Sendable (_ id: Int) async throws -> Station
}

// MARK: - Dependency

extension APIClient: DependencyKey {
    static let liveValue: APIClient = .live()
    static let previewValue: APIClient = .mock()

    static let testValue = APIClient(
        nearbyStations: unimplemented("APIClient.nearbyStations"),
        stationDetail: unimplemented("APIClient.stationDetail")
    )
}

extension DependencyValues {
    var apiClient: APIClient {
        get { self[APIClient.self] }
        set { self[APIClient.self] = newValue }
    }
}
