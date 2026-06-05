//
//  FiltersView.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import ComposableArchitecture
import SwiftUI

/// Controles de filtrado sobre el mapa (RFC §6.2).
struct FiltersView: View {
    @Bindable var store: StoreOf<FiltersFeature>

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 10) {
            // Segmentado se trunca con Dynamic Type grande → menú en tamaños AX.
            if dynamicTypeSize.isAccessibilitySize {
                fuelPicker.pickerStyle(.menu)
            } else {
                fuelPicker.pickerStyle(.segmented)
            }

            HStack {
                Toggle(isOn: $store.selfOnly) {
                    Text("Self service")
                }
                .fixedSize()
                .accessibilityHint(Text("Filtra solo le stazioni self-service"))

                Spacer(minLength: 16)

                Picker("Raggio", selection: $store.radiusKm) {
                    ForEach(RadiusOption.all, id: \.self) { radius in
                        Text("\(Int(radius)) km").tag(radius)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }

    private var fuelPicker: some View {
        Picker("Carburante", selection: $store.fuel) {
            ForEach(FuelType.selectable, id: \.self) { fuel in
                Text(fuel.label).tag(fuel)
            }
        }
    }
}

#Preview {
    FiltersView(
        store: Store(initialState: FiltersFeature.State()) {
            FiltersFeature()
        }
    )
}
