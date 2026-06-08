//
//  ClusterPin.swift
//  FuelMap
//
//  Created on 05/06/2026.
//

import SwiftUI

/// Pin que representa un grupo de estaciones (FM-15). Tap → zoom para desagrupar.
/// Burbuja con el recuento + cápsula "da X" con el tier de la **más barata** dentro,
/// para que un cluster que esconde una ganga siga brillando en verde.
struct ClusterPin: View {
    let count: Int
    let cheapestPrice: Decimal?
    var tier: PriceTier = .mid

    var body: some View {
        VStack(spacing: -6) {
            bubble
            if let cheapestPrice {
                fromPill(cheapestPrice)
            }
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(count) distributori"))
        .accessibilityHint(Text("Tocca per ingrandire"))
    }

    private var bubble: some View {
        Text("\(count)")
            .font(.system(size: 17, weight: .heavy))
            .monospacedDigit()
            .foregroundStyle(Color(.textPrimary))
            .frame(width: 46, height: 46)
            .background(Color(.surfaceElevated), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(tier.fill, lineWidth: 2.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg + 2, style: .continuous)
                    .strokeBorder(Color(.tierStroke), lineWidth: 2)
                    .padding(-2)
            )
            .elevation(.pin)
            .zIndex(1)
    }

    private func fromPill(_ price: Decimal) -> some View {
        HStack(spacing: 2) {
            Text("da").font(.system(size: 9, weight: .semibold)).opacity(0.85)
            Text(price.fuelPriceLabel).font(.system(size: 11, weight: .bold)).monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(tier.fill, in: Capsule())
        .overlay(Capsule().strokeBorder(Color(.tierStroke), lineWidth: 2))
        .elevation(.pin)
        .zIndex(2)
    }
}

#Preview {
    HStack(spacing: 28) {
        ClusterPin(count: 12, cheapestPrice: Decimal(string: "1.789"), tier: .low)
        ClusterPin(count: 5, cheapestPrice: Decimal(string: "1.884"), tier: .mid)
        ClusterPin(count: 42, cheapestPrice: nil, tier: .high)
    }
    .padding(40)
    .background(Color(.surfaceSecondary))
}
