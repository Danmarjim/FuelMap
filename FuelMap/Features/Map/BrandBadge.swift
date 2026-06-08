//
//  BrandBadge.swift
//  FuelMap
//
//  Created on 05/06/2026.
//

import SwiftUI
import UIKit

/// Chip de marca para filas y detalle (design system): rounded rect con hairline que
/// enmarca cualquier logo de forma legible. Con logo → imagen sobre su `logoBackground`
/// (blanco, o navy para Eni amarillo). Sin logo → monograma (`textPrimary`) o pompa
/// genérica (`textSecondary`) sobre `surfaceElevated`. (En el pin el badge es aparte.)
struct BrandBadge: View {
    let brand: BrandStyle
    var size: CGFloat = 28

    private var radius: CGFloat { size * 0.3 }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .overlay(shape.strokeBorder(Color(.separator), lineWidth: 1))
            .accessibilityLabel(brand.displayName)
    }

    @ViewBuilder
    private var content: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if let asset = brand.assetName, UIImage(named: asset) != nil {
            // Logo en su proporción real sobre el fondo de chip de la marca.
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(height: size * 0.6)
                .padding(.vertical, size * 0.2)
                .padding(.horizontal, size * 0.24)
                .background(brand.logoBackground, in: shape)
        } else {
            glyph
                .frame(width: size, height: size)
                .background(Color(.surfaceElevated), in: shape)
        }
    }

    @ViewBuilder
    private var glyph: some View {
        if brand.monogram.isEmpty {
            Image(systemName: "fuelpump.fill")
                .font(.system(size: size * 0.42))
                .foregroundStyle(Color(.textSecondary))
        } else {
            Text(brand.monogram)
                .font(.system(size: size * 0.4, weight: .heavy))
                .foregroundStyle(Color(.textPrimary))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            BrandBadge(brand: .eni, size: 44)
            BrandBadge(brand: .q8, size: 44)
            BrandBadge(brand: .ip, size: 44)
            BrandBadge(brand: .independent, size: 44)
        }
        HStack(spacing: 12) {
            BrandBadge(brand: .eni)
            BrandBadge(brand: .q8)
            BrandBadge(brand: .independent)
        }
    }
    .padding(40)
    .background(Color(.surfaceSecondary))
}
