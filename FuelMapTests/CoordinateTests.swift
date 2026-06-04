//
//  CoordinateTests.swift
//  FuelMapTests
//
//  Created on 04/06/2026.
//

import Testing

@testable import FuelMap

struct CoordinateTests {

    @Test("validated descarta nulas, (0,0) y fuera de rango")
    func coordinate_validated() {
        #expect(Coordinate.validated(latitude: 41.9, longitude: 12.5) != nil)
        #expect(Coordinate.validated(latitude: nil, longitude: 12.5) == nil)
        #expect(Coordinate.validated(latitude: 0, longitude: 0) == nil)
        #expect(Coordinate.validated(latitude: 91, longitude: 12.5) == nil)
        #expect(Coordinate.validated(latitude: 41.9, longitude: 200) == nil)
    }

    @Test("distance: misma coordenada = 0; Roma↔Milán ≈ 477 km")
    func coordinate_distance() {
        let rome = Coordinate(latitude: 41.9028, longitude: 12.4964)
        let milan = Coordinate(latitude: 45.4642, longitude: 9.1900)

        #expect(rome.distance(to: rome) == 0)

        let kilometers = rome.distance(to: milan) / 1000
        // Distancia real ~477 km; toleramos ±10 km.
        #expect(kilometers > 467 && kilometers < 487)
    }
}
