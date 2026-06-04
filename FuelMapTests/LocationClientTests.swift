//
//  LocationClientTests.swift
//  FuelMapTests
//
//  Created on 04/06/2026.
//

import CoreLocation
import Testing

@testable import FuelMap

/// Tests del contrato de `LocationClient` con stubs inyectables.
/// La lógica real sobre `CLLocationManager` (live) requiere prueba de integración/manual.
struct LocationClientTests {

    @Test("notDetermined: requestWhenInUse devuelve el estado tras la decisión")
    func locationClient_notDetermined_requestsAuthorization() async {
        let client = LocationClient(
            authorizationStatus: { .notDetermined },
            requestWhenInUse: { .authorizedWhenInUse },
            currentLocation: { Coordinate(latitude: 41.9, longitude: 12.5) }
        )

        #expect(client.authorizationStatus() == .notDetermined)
        let granted = await client.requestWhenInUse()
        #expect(granted == .authorizedWhenInUse)
    }

    @Test("denied: currentLocation lanza authorizationDenied")
    func locationClient_denied_currentLocationThrows() async {
        let client = LocationClient(
            authorizationStatus: { .denied },
            requestWhenInUse: { .denied },
            currentLocation: { throw LocationError.authorizationDenied }
        )

        #expect(client.authorizationStatus() == .denied)
        await #expect(throws: LocationError.authorizationDenied) {
            _ = try await client.currentLocation()
        }
    }

    @Test("authorized: currentLocation devuelve la coordenada")
    func locationClient_authorized_returnsCoordinate() async throws {
        let expected = Coordinate(latitude: 45.46, longitude: 9.19)
        let client = LocationClient(
            authorizationStatus: { .authorizedWhenInUse },
            requestWhenInUse: { .authorizedWhenInUse },
            currentLocation: { expected }
        )

        let coordinate = try await client.currentLocation()
        #expect(coordinate == expected)
    }
}
