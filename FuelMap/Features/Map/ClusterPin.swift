//
//  ClusterPin.swift
//  FuelMap
//
//  Created on 05/06/2026.
//

import SwiftUI

/// Pin que representa un grupo de estaciones (FM-15). Tap → zoom para desagrupar.
struct ClusterPin: View {
    let count: Int
    let cheapestPrice: Decimal?

    var body: some View {
        Text("\(count)")
            .font(.callout.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .frame(minWidth: 34, minHeight: 34)
            .padding(4)
            .background(Color.blue.gradient, in: Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Circle())
            .shadow(radius: 1.5)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(count) distributori"))
            .accessibilityHint(Text("Tocca per ingrandire"))
    }
}

#Preview {
    HStack(spacing: 24) {
        ClusterPin(count: 5, cheapestPrice: Decimal(string: "1.789"))
        ClusterPin(count: 42, cheapestPrice: nil)
    }
    .padding()
}
