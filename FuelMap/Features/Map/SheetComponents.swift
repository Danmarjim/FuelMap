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
    var height: CGFloat = 34
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
            .frame(height: height)
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

    private var stale: Bool { PriceFreshness.isStale(date) }

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

/// Barrido de carga (shimmer) sobre formas placeholder. Respeta Reduce Motion.
private struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var move = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    LinearGradient(
                        colors: [.white.opacity(0), .white.opacity(0.5), .white.opacity(0)],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .rotationEffect(.degrees(18))
                    .offset(x: move ? 260 : -260)
                    .blendMode(.overlay)
                }
            }
            .mask(content)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { move = true }
            }
    }
}

extension View {
    /// Aplica un barrido de carga; estático si el usuario pidió Reduce Motion.
    func shimmer() -> some View { modifier(Shimmer()) }
}

/// Fila placeholder de carga (design system `sk`).
struct SkeletonRow: View {
    private var bar: Color { Color(.surfaceTertiary) }

    var body: some View {
        HStack(spacing: Spacing.s4) {
            RoundedRectangle(cornerRadius: 9, style: .continuous).fill(bar).frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: Spacing.s2) {
                Capsule().fill(bar).frame(width: 150, height: 14)
                Capsule().fill(bar).frame(width: 84, height: 11)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: Spacing.s2) {
                Capsule().fill(bar).frame(width: 58, height: 16)
                Capsule().fill(bar).frame(width: 44, height: 16)
            }
        }
        .padding(.horizontal, Spacing.s5)
        .padding(.vertical, Spacing.s4)
        .frame(minHeight: 64)
    }
}

/// Lista de filas placeholder con barrido (carga de la hoja de lista).
struct SkeletonList: View {
    var rows = 6

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { _ in SkeletonRow() }
        }
        .shimmer()
        .accessibilityHidden(true)
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
                        Text(price.fuelPriceValue).font(.fmPriceRow).foregroundStyle(Color(.textPrimary))
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
