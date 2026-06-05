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
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
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
