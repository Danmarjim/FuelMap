//
//  FuelTypeTests.swift
//  FuelMapTests
//
//  Created on 04/06/2026.
//

import Testing

@testable import FuelMap

struct FuelTypeTests {

    @Test("Todos los rawValue canónicos del backend mapean a un caso")
    func fuelType_mapsAllCanonicalRawValues() {
        let canonical = ["benzina", "gasolio", "gpl", "metano", "hvo", "altro"]
        for raw in canonical {
            #expect(FuelType(rawValue: raw) != nil, "Falta el caso para \(raw)")
        }
        #expect(FuelType.allCases.count == canonical.count)
    }

    @Test("Un rawValue desconocido no mapea (el mapper aplica el fallback .altro)")
    func fuelType_unknownRawValueIsNil() {
        #expect(FuelType(rawValue: "Hi-Q Diesel") == nil)
    }
}
