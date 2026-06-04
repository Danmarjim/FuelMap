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

    var body: some View {
        VStack(spacing: 10) {
            Picker("Carburante", selection: $store.fuel) {
                ForEach(FuelType.selectable, id: \.self) { fuel in
                    Text(fuel.label).tag(fuel)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Toggle(isOn: $store.selfOnly) {
                    Text("Self service")
                }
                .fixedSize()

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
}

#Preview {
    FiltersView(
        store: Store(initialState: FiltersFeature.State()) {
            FiltersFeature()
        }
    )
}
