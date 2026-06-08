//
//  TokenGallery.swift
//  FuelMap
//
//  Created on 08/06/2026.
//

import SwiftUI

/// Galería de tokens del design system para validación visual en `#Preview`.
/// No se usa en la app; sirve de documentación viva (claro/oscuro) durante el restyle.
struct TokenGallery: View {
    private let groups: [(String, [String])] = [
        ("Brand", ["brandPrimary", "brandPrimaryFill", "brandPrimaryPressed", "brandTint", "brandSurface"]),
        ("Surfaces", ["surface", "surfaceElevated", "surfaceSecondary", "surfaceTertiary"]),
        ("Text", ["textPrimary", "textSecondary", "textTertiary"]),
        ("Lines", ["separator", "separatorStrong"]),
        ("Price tiers", ["priceCheap", "priceMid", "priceHigh"]),
        ("Tier ink", ["priceCheapInk", "priceMidInk", "priceHighInk"]),
        ("Tier surface", ["priceCheapSurface", "priceMidSurface", "priceHighSurface"]),
        ("Functional", ["success", "warning", "warningSurface", "error", "errorSurface"]),
        ("Accent", ["cheapestGold"])
    ]
    private let cols = [GridItem(.adaptive(minimum: 96), spacing: Spacing.s3)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s7) {
                typeSample
                ForEach(groups, id: \.0) { title, names in
                    VStack(alignment: .leading, spacing: Spacing.s3) {
                        Text(title).font(.fmTitle3)
                        LazyVGrid(columns: cols, spacing: Spacing.s3) {
                            ForEach(names, id: \.self) { swatch($0) }
                        }
                    }
                }
                elevationSample
            }
            .padding(Spacing.s5)
        }
        .background(Color(.surface))
    }

    private func swatch(_ name: String) -> some View {
        VStack(spacing: Spacing.s2) {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color(name, bundle: .main))
                .frame(height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(Color(.separator))
                )
            Text(name).font(.fmCaption2).foregroundStyle(Color(.textSecondary))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    private var typeSample: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text("Stazioni vicine").font(.fmLargeTitle)
            Text("Self vs Servito").font(.fmTitle3)
            Text("Via Roma 42 · aggiornato 4 ore fa").font(.fmBody)
            Text("1.842").font(.fmPriceRow).foregroundStyle(Color(.priceCheapInk))
        }
        .foregroundStyle(Color(.textPrimary))
    }

    private var elevationSample: some View {
        HStack(spacing: Spacing.s5) {
            ForEach(["e1", "e2", "pin", "e3"], id: \.self) { label in
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Color(.surfaceElevated))
                    .frame(width: 64, height: 48)
                    .elevation(elevation(for: label))
                    .overlay(Text(label).font(.fmCaption2).foregroundStyle(Color(.textSecondary)))
            }
        }
        .padding(.top, Spacing.s3)
    }

    private func elevation(for label: String) -> Elevation {
        switch label {
        case "e1": return .e1
        case "e2": return .e2
        case "pin": return .pin
        default: return .e3
        }
    }
}

#Preview("Tokens · Light") {
    TokenGallery().preferredColorScheme(.light)
}

#Preview("Tokens · Dark") {
    TokenGallery().preferredColorScheme(.dark)
}
