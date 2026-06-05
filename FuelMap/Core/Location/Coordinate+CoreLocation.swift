//
//  Coordinate+CoreLocation.swift
//  FuelMap
//
//  Created on 05/06/2026.
//

import CoreLocation

extension Coordinate {
    /// Conversión a `CLLocationCoordinate2D` (MapKit/CoreLocation).
    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
