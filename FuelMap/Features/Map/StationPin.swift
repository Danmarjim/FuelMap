//
//  StationPin.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import Foundation
import SwiftUI

/// Pin de mapa que muestra el precio del combustible seleccionado.
/// `isCheapest` se usará en FM-10 para destacar la estación más barata.
struct StationPin: View {
    let name: String
    let fuel: FuelType
    let price: Decimal?
    var brand: BrandStyle = .independent
    var tier: PriceTier = .mid
    var isCheapest: Bool = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // Color por nivel de precio (verde/naranja/rojo) (FM-18).
    private var tint: Color { tier.color }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 3) {
                // Líder: estrella si es la más barata; si no, monograma de marca;
                // y pumpa genérica para independientes/sin marca.
                leadingGlyph
                    .font(.caption2.weight(.heavy))
                // En tamaños de accesibilidad ocultamos el texto para no desbordar
                // el pin en el mapa; el precio sigue en el accessibilityLabel.
                if !dynamicTypeSize.isAccessibilitySize {
                    Text(priceText)
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .foregroundStyle(.white)
            .background(tint, in: Capsule())
            .overlay(Capsule().strokeBorder(.white, lineWidth: 1))

            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 9))
                .foregroundStyle(tint)
                .offset(y: -3)
        }
        .shadow(radius: 1.5)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
    }

    @ViewBuilder
    private var leadingGlyph: some View {
        if isCheapest {
            Image(systemName: "star.fill")
        } else if !brand.monogram.isEmpty {
            Text(brand.monogram)
        } else {
            Image(systemName: "fuelpump.fill")
        }
    }

    private var priceText: String {
        price?.fuelPriceLabel ?? "—"
    }

    private var accessibilityText: String {
        var text = "\(name), \(fuel.label) \(priceText)"
        if !brand.monogram.isEmpty { text += ", \(brand.displayName)" }
        if isCheapest { text += ", " + String(localized: "il più economico") }
        return text
    }
}

#Preview {
    HStack(spacing: 20) {
        StationPin(name: "Eni", fuel: .benzina, price: Decimal(string: "1.879"), brand: .eni, tier: .high)
        StationPin(
            name: "Tamoil", fuel: .benzina, price: Decimal(string: "1.849"),
            brand: .tamoil, tier: .low, isCheapest: true
        )
        StationPin(name: "Q8", fuel: .benzina, price: Decimal(string: "1.86"), brand: .q8, tier: .mid)
    }
    .padding()
}
