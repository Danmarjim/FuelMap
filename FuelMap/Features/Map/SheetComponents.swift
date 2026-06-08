//
//  SheetComponents.swift
//  FuelMap
//
//  Created on 08/06/2026.
//

import SwiftUI

/// Etiqueta de nivel de precio: forma + palabra sobre fondo tintado (redundancia
/// daltónica). Design system `tier-tag`.
struct TierTag: View {
    let tier: PriceTier

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tier.symbolName).font(.system(size: 9, weight: .bold))
            Text(tier.label).font(.system(size: 10.5, weight: .bold)).textCase(.uppercase)
        }
        .foregroundStyle(tier.ink)
        .padding(.horizontal, 7)
        .frame(height: 20)
        .background(tier.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

/// Distintivo "más barata" en oro adaptativo (design system `best-flag`).
struct BestFlag: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill").font(.system(size: 9))
            Text("Più basso").font(.fmCaption2.weight(.bold)).textCase(.uppercase)
        }
        .foregroundStyle(Color(.goldInk))
    }
}

/// Pill de orden (Prezzo / Distanza) para la `sortbar` de las hojas.
struct SortPill: View {
    let option: StationSort
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s2) {
                Image(systemName: option == .price ? "arrow.up.arrow.down" : "location.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text(option.label).font(.fmFootnote.weight(.semibold))
            }
            .foregroundStyle(isActive ? Color(.brandPrimary) : Color(.textPrimary))
            .padding(.horizontal, Spacing.s4)
            .frame(height: 34)
            .background(isActive ? Color(.brandSurface) : Color(.surfaceTertiary), in: Capsule())
            .overlay { if isActive { Capsule().strokeBorder(Color(.brandPrimary).opacity(0.3)) } }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}

/// Cabecera de hoja: título + recuento + botón cerrar.
struct SheetHeader: View {
    let title: LocalizedStringKey
    var count: Int?
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: Spacing.s4) {
            Text(title).font(.fmTitle2).foregroundStyle(Color(.textPrimary))
            if let count {
                Text("\(count)").font(.fmSubheadline).monospacedDigit().foregroundStyle(Color(.textSecondary))
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(.textSecondary))
                    .frame(width: 32, height: 32)
                    .background(Color(.surfaceTertiary), in: Circle())
            }
            .accessibilityLabel(Text("Chiudi"))
        }
        .padding(.horizontal, Spacing.s5)
        .padding(.top, Spacing.s4)
        .padding(.bottom, Spacing.s3)
    }
}

/// Estado vacío/error dentro de una hoja (design system `state-block`).
struct SheetEmptyState: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var tint: Color = Color(.textTertiary)
    var tintSurface: Color = Color(.surfaceTertiary)

    var body: some View {
        VStack(spacing: Spacing.s2) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .foregroundStyle(tint)
                .frame(width: 56, height: 56)
                .background(tintSurface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .padding(.bottom, Spacing.s2)
            Text(title).font(.fmHeadline).foregroundStyle(Color(.textPrimary))
            Text(message)
                .font(.fmSubheadline)
                .foregroundStyle(Color(.textSecondary))
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.s8)
        .frame(maxWidth: .infinity)
    }
}

/// Píldora de frescura del precio (design system `fresh-pill`).
struct FreshnessPill: View {
    let date: Date

    private var stale: Bool { date < Date.now.addingTimeInterval(-2 * 24 * 3600) }

    var body: some View {
        HStack(spacing: Spacing.s2) {
            Image(systemName: stale ? "exclamationmark.triangle.fill" : "clock")
                .font(.system(size: 11))
            Text(stale ? "Vecchio" : "Agg.") + Text(" ") + Text(date, format: .relative(presentation: .named))
        }
        .font(.fmFootnote.weight(.semibold))
        .foregroundStyle(stale ? Color(.warning) : Color(.textSecondary))
        .padding(.horizontal, Spacing.s3)
        .padding(.vertical, 5)
        .background(stale ? Color(.warningSurface) : Color(.surfaceTertiary), in: Capsule())
        .overlay { if stale { Capsule().strokeBorder(Color(.warning).opacity(0.28)) } }
    }
}

/// Fila de estación para lista/favoritos (design system `lrow`).
struct StationRow: View {
    let brand: BrandStyle
    let name: String
    var distance: String?
    var price: Decimal?
    var tier: PriceTier?
    var isCheapest: Bool = false
    var trailingStar: Bool = false

    var body: some View {
        HStack(spacing: Spacing.s4) {
            BrandBadge(brand: brand, size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.fmBody.weight(.semibold))
                    .foregroundStyle(Color(.textPrimary))
                    .lineLimit(1)
                if isCheapest || distance != nil {
                    HStack(spacing: Spacing.s3) {
                        if isCheapest { BestFlag() }
                        if let distance {
                            Label {
                                Text(distance).monospacedDigit()
                            } icon: {
                                Image(systemName: "location.north.fill")
                            }
                            .font(.fmFootnote)
                            .foregroundStyle(Color(.textSecondary))
                        }
                    }
                }
            }
            Spacer(minLength: Spacing.s3)
            if let price {
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(price.fuelPriceLabel).font(.fmPriceRow).foregroundStyle(Color(.textPrimary))
                        Text("€/L").font(.fmCaption2).foregroundStyle(Color(.textTertiary))
                    }
                    if let tier { TierTag(tier: tier) }
                }
            }
            if trailingStar {
                Image(systemName: "star.fill").font(.system(size: 20)).foregroundStyle(Color(.goldInk))
            }
        }
        .padding(.horizontal, Spacing.s5)
        .padding(.vertical, Spacing.s4)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
    }
}
