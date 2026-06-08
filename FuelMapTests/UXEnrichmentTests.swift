//
//  UXEnrichmentTests.swift
//  FuelMapTests
//
//  Created on 05/06/2026.
//

import Foundation
import Testing

@testable import FuelMap

struct PriceTiersTests {
    private func dec(_ string: String) -> Decimal { Decimal(string: string) ?? .zero }

    @Test("Reparte por terciles: barato→low, medio→mid, caro→high")
    func tiers_terciles() {
        let prices = (1...9).map { Decimal($0) }
        let tiers = PriceTiers(prices: prices)
        #expect(tiers.tier(for: 2) == .low)
        #expect(tiers.tier(for: 5) == .mid)
        #expect(tiers.tier(for: 9) == .high)
    }

    @Test("Menos de 3 precios o todos iguales → mid (sin clasificar)")
    func tiers_degenerate() {
        #expect(PriceTiers(prices: [dec("1.8"), dec("1.9")]).tier(for: dec("1.8")) == .mid)
        let same = Array(repeating: dec("1.8"), count: 5)
        #expect(PriceTiers(prices: same).tier(for: dec("1.8")) == .mid)
    }

    @Test("Cada tier tiene forma y etiqueta propias (redundancia daltónica)")
    func tier_shapeAndLabel() {
        let shapes = Set([PriceTier.low, .mid, .high].map(\.symbolName))
        #expect(shapes.count == 3)
        #expect(PriceTier.low.symbolName == "arrowtriangle.up.fill")
        #expect(PriceTier.high.symbolName == "arrowtriangle.down.fill")
        let labels = Set([PriceTier.low, .mid, .high].map(\.label))
        #expect(labels.count == 3)
    }
}

struct BrandStyleTests {
    @Test("Normaliza las marcas top del MIMIT")
    func brand_mapping() {
        #expect(BrandStyle.from("Agip Eni") == .eni)
        #expect(BrandStyle.from("ENI") == .eni)
        #expect(BrandStyle.from("Q8") == .q8)
        #expect(BrandStyle.from("Esso") == .esso)
        #expect(BrandStyle.from("Tamoil") == .tamoil)
        #expect(BrandStyle.from("Shell") == .shell)
        #expect(BrandStyle.from("Api-Ip") == .ip)
        #expect(BrandStyle.from("Pompe Bianche") == .independent)
        #expect(BrandStyle.from("") == .independent)
        // Marca desconocida → genérico (no crashea, monograma = inicial).
        #expect(BrandStyle.from("Marca Rara").monogram == "M")
    }
}

struct NavAppTests {
    @Test("URLs de indicaciones por app con el destino correcto")
    func navapp_urls() {
        let coordinate = Coordinate(latitude: 41.9, longitude: 12.5)
        #expect(NavApp.appleMaps.directionsURL(to: coordinate)?.absoluteString == "maps://?daddr=41.9,12.5")
        #expect(
            NavApp.googleMaps.directionsURL(to: coordinate)?.absoluteString
                == "comgooglemaps://?daddr=41.9,12.5&directionsmode=driving"
        )
        #expect(NavApp.waze.directionsURL(to: coordinate)?.absoluteString == "waze://?ll=41.9,12.5&navigate=yes")
    }
}
