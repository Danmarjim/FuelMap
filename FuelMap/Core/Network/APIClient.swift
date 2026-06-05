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
/// `liveValue` es **temporalmente un mock** (fixtures) hasta que el backend exista
/// (FM-2 esquema/RPC, FM-3 sync). Migrar a Supabase = sustituir `liveValue` por la
/// implementación real sobre `supabase-swift` (ver ADR-001). El contrato no cambia.
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
    /// TEMP: mock con fixtures hasta FM-2/FM-3. Reemplazar por Supabase real (ADR-001).
    static let liveValue: APIClient = .mock()
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
