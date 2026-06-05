//
//  BrandBadge.swift
//  FuelMap
//
//  Created on 05/06/2026.
//

import SwiftUI
import UIKit

/// Badge de marca: logo oficial si existe el asset, si no círculo de color + monograma (FM-16).
struct BrandBadge: View {
    let brand: BrandStyle
    var size: CGFloat = 28

    var body: some View {
        if let asset = brand.assetName, UIImage(named: asset) != nil {
            // Logo sobre un chip de color de marca (opción 1): garantiza contraste
            // para cualquier color de logo. Se ajusta por altura para respetar su
            // proporción real (emblema cuadrado → cuadrado; wordmark → apaisado).
            let radius = size * 0.22
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(height: size * 0.64)
                .padding(.vertical, size * 0.18)
                .padding(.horizontal, size * 0.22)
                .background(brand.logoBackground, in: shape)
                .overlay(shape.strokeBorder(Color.primary.opacity(0.08)))
                .accessibilityLabel(brand.displayName)
        } else {
            Text(brand.monogram.isEmpty ? "•" : brand.monogram)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(brand.color, in: Circle())
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        BrandBadge(brand: .eni)
        BrandBadge(brand: .q8)
        BrandBadge(brand: .ip)
        BrandBadge(brand: .independent)
    }
    .padding()
}
