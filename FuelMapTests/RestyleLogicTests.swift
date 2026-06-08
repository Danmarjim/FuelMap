//
//  RestyleLogicTests.swift
//  FuelMapTests
//
//  Created on 08/06/2026.
//

import Foundation
import Testing

@testable import FuelMap

struct FuelVariantBuilderTests {
    private func price(_ fuel: FuelType, _ raw: String, _ value: String, isSelf: Bool) -> FuelPrice {
        FuelPrice(fuel: fuel, fuelRaw: raw, price: Decimal(string: value) ?? .zero, isSelf: isSelf, communicatedAt: nil)
    }

    private func station(_ prices: [FuelPrice]) -> Station {
        Station(
            id: 1, name: "X", brand: nil, address: nil, municipality: nil, province: nil,
            coordinate: Coordinate(latitude: 41.9, longitude: 12.5), prices: prices
        )
    }

    @Test("Agrupa por producto real y separa self/servito")
    func variants_groupSelfServito() throws {
        let sample = station([
            price(.benzina, "Benzina", "1.879", isSelf: true),
            price(.benzina, "Benzina", "1.999", isSelf: false),
            price(.gasolio, "Gasolio", "1.789", isSelf: true)
        ])
        let variants = FuelVariantBuilder.variants(for: sample, selected: .benzina)
        #expect(variants.count == 2)
        let benzina = try #require(variants.first { $0.name == "Benzina" })
        #expect(benzina.selfPrice == Decimal(string: "1.879"))
        #expect(benzina.servitoPrice == Decimal(string: "1.999"))
        let gasolio = try #require(variants.first { $0.name == "Gasolio" })
        #expect(gasolio.selfPrice == Decimal(string: "1.789"))
        #expect(gasolio.servitoPrice == nil)
    }

    @Test("El combustible filtrado va primero")
    func variants_selectedFirst() {
        let sample = station([
            price(.benzina, "Benzina", "1.879", isSelf: true),
            price(.gasolio, "Gasolio", "1.789", isSelf: true),
            price(.gpl, "GPL", "0.719", isSelf: true)
        ])
        #expect(FuelVariantBuilder.variants(for: sample, selected: .gasolio).first?.fuel == .gasolio)
        #expect(FuelVariantBuilder.variants(for: sample, selected: .gpl).first?.fuel == .gpl)
    }

    @Test("Variantes distintas del mismo combustible se conservan por fuelRaw")
    func variants_keepsDistinctRaw() {
        let sample = station([
            price(.benzina, "Benzina", "1.879", isSelf: true),
            price(.benzina, "Benzina Plus 98", "2.099", isSelf: true)
        ])
        let variants = FuelVariantBuilder.variants(for: sample, selected: .benzina)
        #expect(Set(variants.map(\.name)) == ["Benzina", "Benzina Plus 98"])
    }
}

struct PriceFreshnessTests {
    private let now = Date(timeIntervalSince1970: 1_000_000_000)

    @Test("Precio reciente no es obsoleto; más de 48 h sí")
    func freshness_threshold() {
        #expect(PriceFreshness.isStale(now.addingTimeInterval(-3600), now: now) == false)
        #expect(PriceFreshness.isStale(now.addingTimeInterval(-47 * 3600), now: now) == false)
        #expect(PriceFreshness.isStale(now.addingTimeInterval(-49 * 3600), now: now) == true)
        #expect(PriceFreshness.isStale(now.addingTimeInterval(-5 * 24 * 3600), now: now) == true)
    }
}
