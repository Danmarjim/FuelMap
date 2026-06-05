//
//  LocationClient.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import ComposableArchitecture
import CoreLocation

/// Errores de la capa de ubicación.
enum LocationError: Error, Equatable, Sendable {
    /// No hay autorización de ubicación (denegada/restringida).
    case authorizationDenied
    /// CoreLocation no pudo obtener una ubicación.
    case locationUnavailable
}

/// Dependencia que envuelve CoreLocation (RFC §3.3, §6.1).
///
/// - `authorizationStatus`: lectura síncrona y thread-safe del último estado conocido.
/// - `requestWhenInUse`: solicita autorización *when in use* si está sin determinar.
/// - `currentLocation`: una ubicación puntual; lanza `LocationError` si no hay permiso o falla.
struct LocationClient: Sendable {
    var authorizationStatus: @Sendable () -> CLAuthorizationStatus
    var requestWhenInUse: @Sendable () async -> CLAuthorizationStatus
    var currentLocation: @Sendable () async throws -> Coordinate
}

// MARK: - Live

extension LocationClient: DependencyKey {
    static var liveValue: LocationClient {
        LocationClient(
            authorizationStatus: { LocationCoordinator.statusBox.value },
            requestWhenInUse: { await LocationCoordinator.shared.requestWhenInUse() },
            currentLocation: { try await LocationCoordinator.shared.currentLocation() }
        )
    }

    static var testValue: LocationClient {
        LocationClient(
            authorizationStatus: unimplemented(
                "LocationClient.authorizationStatus", placeholder: .notDetermined
            ),
            requestWhenInUse: unimplemented(
                "LocationClient.requestWhenInUse", placeholder: .notDetermined
            ),
            currentLocation: unimplemented("LocationClient.currentLocation")
        )
    }
}

extension DependencyValues {
    var locationClient: LocationClient {
        get { self[LocationClient.self] }
        set { self[LocationClient.self] = newValue }
    }
}

// MARK: - CoreLocation coordinator

/// Propietario del `CLLocationManager`, aislado al main actor (por tanto `Sendable`).
/// Puentea los callbacks del delegate a `async/await` mediante continuations.
@MainActor
private final class LocationCoordinator: NSObject {
    static let shared = LocationCoordinator()

    /// Último estado de autorización, accesible de forma síncrona y thread-safe
    /// desde cualquier hilo (el coordinador lo actualiza en el main actor).
    nonisolated static let statusBox = LockIsolated<CLAuthorizationStatus>(.notDetermined)

    private let manager = CLLocationManager()
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuations: [CheckedContinuation<Coordinate, Error>] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        let status = manager.authorizationStatus
        Self.statusBox.setValue(status)
    }

    func requestWhenInUse() async -> CLAuthorizationStatus {
        let current = manager.authorizationStatus
        guard current == .notDetermined else {
            Self.statusBox.setValue(current)
            return current
        }
        return await withCheckedContinuation { continuation in
            MainActor.assumeIsolated {
                authContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        }
    }

    func currentLocation() async throws -> Coordinate {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            break
        default:
            throw LocationError.authorizationDenied
        }
        return try await withCheckedThrowingContinuation { continuation in
            MainActor.assumeIsolated {
                locationContinuations.append(continuation)
                manager.requestLocation()
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationCoordinator: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Extraer el valor Sendable fuera del límite del main actor (no enviar `manager`).
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            Self.statusBox.setValue(status)
            guard status != .notDetermined, let continuation = authContinuation else { return }
            authContinuation = nil
            continuation.resume(returning: status)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        let coordinate = locations.last.map { Coordinate($0.coordinate) }
        MainActor.assumeIsolated {
            guard let coordinate else { return }
            let pending = locationContinuations
            locationContinuations.removeAll()
            pending.forEach { $0.resume(returning: coordinate) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            let pending = locationContinuations
            locationContinuations.removeAll()
            pending.forEach { $0.resume(throwing: LocationError.locationUnavailable) }
        }
    }
}
