//
//  GeocodingClient.swift
//  FuelMap
//
//  Created on 01/09/2026.
//

import ComposableArchitecture
import MapKit

/// Errores de geocodificación.
enum GeocodingError: Error, Equatable, Sendable {
    /// La búsqueda no encontró ningún lugar.
    case noResults
    /// Fallo de red/servidor — antes se reportaba también como `.noResults`, lo que
    /// hacía creer al usuario que su ciudad "no existe" cuando en realidad no hay
    /// conexión (única salida real de quien ya denegó el permiso de ubicación;
    /// review RELEASE-001 F1-F2, A-6).
    case network

    var userMessage: String {
        switch self {
        case .noResults:
            return String(localized: "Nessun risultato per questa ricerca.")
        case .network:
            return String(localized: "Errore di connessione. Riprova.")
        }
    }
}

/// Búsqueda de lugares por texto libre (ciudad, dirección, punto de interés), para
/// que un usuario sin permiso de ubicación (o que simplemente quiere mirar otra
/// zona) pueda centrar el mapa donde le interese.
struct GeocodingClient: Sendable {
    var search: @Sendable (_ query: String) async throws -> Coordinate
}

// MARK: - Dependency

extension GeocodingClient: DependencyKey {
    static let liveValue = GeocodingClient(
        search: { query in
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.resultTypes = [.address, .pointOfInterest]
            let response = try await MKLocalSearch(request: request).start()
            guard let coordinate = response.mapItems.first?.placemark.coordinate else {
                throw GeocodingError.noResults
            }
            return Coordinate(coordinate)
        }
    )

    static let testValue = GeocodingClient(
        search: unimplemented("GeocodingClient.search")
    )

    static let previewValue = GeocodingClient(search: { _ in .italyDefault })
}

extension DependencyValues {
    var geocodingClient: GeocodingClient {
        get { self[GeocodingClient.self] }
        set { self[GeocodingClient.self] = newValue }
    }
}
