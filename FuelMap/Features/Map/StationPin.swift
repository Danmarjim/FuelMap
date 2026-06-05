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
    var isCheapest: Bool = false

    private var tint: Color { isCheapest ? .green : .blue }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 3) {
                Image(systemName: "fuelpump.fill")
                    .font(.caption2)
                Text(priceText)
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
    }

    private var priceText: String {
        price?.fuelPriceLabel ?? "—"
    }

    private var accessibilityText: String {
        var text = "\(name), \(fuel.label) \(priceText)"
        if isCheapest {
            text += ", " + String(localized: "il più economico")
        }
        return text
    }
}

#Preview {
    HStack(spacing: 20) {
        StationPin(name: "Eni Roma Centro", fuel: .benzina, price: Decimal(string: "1.879"))
        StationPin(name: "Tamoil Ostiense", fuel: .benzina, price: Decimal(string: "1.849"), isCheapest: true)
        StationPin(name: "Sconosciuto", fuel: .benzina, price: nil)
    }
    .padding()
}
