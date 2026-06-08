//
//  StationPin.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import Foundation
import SwiftUI

/// Pin de mapa: cápsula con badge de marca, forma de tier, precio y cola.
/// Legible sobre cualquier tile (relleno opaco de tier + halo `tierStroke` + sombra).
/// Estados: por defecto · seleccionado (más grande, con etiqueta de tier) · más barata
/// (badge dorado + anillo + corona). Design system, ver `.claude/design/`.
struct StationPin: View {
    let name: String
    let fuel: FuelType
    let price: Decimal?
    var brand: BrandStyle = .independent
    var tier: PriceTier = .mid
    var isCheapest: Bool = false
    var isSelected: Bool = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var badgeSize: CGFloat { isSelected ? 34 : 28 }

    var body: some View {
        VStack(spacing: 0) {
            capsule
                .overlay(alignment: .top) { crown }
            tail
        }
        // El precio del pin se capa a Large para no desbordar sobre el mapa;
        // VoiceOver anuncia el detalle completo vía accessibilityLabel.
        .dynamicTypeSize(...DynamicTypeSize.large)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .zIndex(isSelected ? 1 : 0)
        .animation(reduceMotion ? nil : .spring(duration: 0.25), value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Cápsula

    private var capsule: some View {
        HStack(spacing: isSelected ? 8 : 6) {
            badge
            Image(systemName: tier.symbolName)
                .font(.system(size: isSelected ? 12 : 11, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.18), radius: 0, y: 1)
            if !dynamicTypeSize.isAccessibilitySize {
                Text(priceText)
                    .font(.fmPinPrice)
                    .foregroundStyle(.white)
                if isSelected {
                    Text(tier.label)
                        .font(.system(size: 9, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 5))
                }
            }
        }
        .padding(isSelected ? 4 : 3)
        .padding(.trailing, isSelected ? 11 : 8)
        .background(tier.fill, in: Capsule())
        .overlay(Capsule().strokeBorder(Color(.tierStroke), lineWidth: isSelected ? 2.5 : 2))
        .overlay { if isCheapest { goldRing } }
        .elevation(isSelected ? .pinSelected : .pin)
    }

    private var badge: some View {
        ZStack {
            Circle().fill(isCheapest ? Color(.cheapestGold) : .white)
            badgeContent
        }
        .frame(width: badgeSize, height: badgeSize)
        .overlay(Circle().strokeBorder(.black.opacity(0.06), lineWidth: 1))
    }

    @ViewBuilder
    private var badgeContent: some View {
        if isCheapest {
            Image(systemName: "star.fill")
                .font(.system(size: badgeSize * 0.46, weight: .bold))
                .foregroundStyle(Color(red: 0.23, green: 0.16, blue: 0))
        } else if !brand.monogram.isEmpty {
            Text(brand.monogram)
                .font(.system(size: badgeSize * 0.36, weight: .heavy))
                .foregroundStyle(tier.fill)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        } else {
            Image(systemName: "fuelpump.fill")
                .font(.system(size: badgeSize * 0.44))
                .foregroundStyle(tier.fill)
        }
    }

    private var goldRing: some View {
        Capsule()
            .strokeBorder(Color(.cheapestGold), lineWidth: isSelected ? 2.5 : 2)
            .padding(isSelected ? -3 : -2.5)
    }

    @ViewBuilder
    private var crown: some View {
        if isCheapest {
            Image(systemName: "crown.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(.cheapestGold))
                .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                .offset(y: -13)
        }
    }

    private var tail: some View {
        ZStack {
            DownTriangle().fill(Color(.tierStroke)).frame(width: 16, height: 10)
            DownTriangle().fill(tier.fill).frame(width: 12, height: 7)
        }
        .offset(y: -1)
    }

    private var priceText: String {
        price?.fuelPriceValue ?? "—"
    }

    private var accessibilityText: String {
        let spokenPrice = price?.fuelPriceLabel ?? "—"
        var text = "\(name), \(fuel.label) \(spokenPrice)"
        if !brand.monogram.isEmpty { text += ", \(brand.displayName)" }
        text += ", \(tier.label)"
        if isCheapest { text += ", " + String(localized: "il più economico") }
        return text
    }
}

/// Triángulo apuntando hacia abajo (cola del pin).
struct DownTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 28) {
        HStack(spacing: 20) {
            StationPin(name: "Q8", fuel: .benzina, price: Decimal(string: "1.799"), brand: .q8, tier: .low)
            StationPin(name: "IP", fuel: .benzina, price: Decimal(string: "1.879"), brand: .ip, tier: .mid)
            StationPin(name: "Esso", fuel: .benzina, price: Decimal(string: "2.014"), brand: .esso, tier: .high)
        }
        HStack(spacing: 20) {
            StationPin(
                name: "Tamoil", fuel: .benzina, price: Decimal(string: "1.789"),
                brand: .tamoil, tier: .low, isCheapest: true
            )
            StationPin(
                name: "Eni", fuel: .benzina, price: Decimal(string: "1.872"),
                brand: .eni, tier: .mid, isSelected: true
            )
        }
    }
    .padding(40)
    .background(Color(.surfaceSecondary))
}
