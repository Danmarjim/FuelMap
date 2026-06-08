//
//  FiltersView.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import ComposableArchitecture
import SwiftUI

/// Barra de filtros sobre el mapa (RFC §6.2), reestilizada al design system (R3).
/// El orden (`sort`) vive en `MapFeature`; se inyecta como binding porque la barra
/// lo muestra junto a los filtros.
struct FiltersView: View {
    @Bindable var store: StoreOf<FiltersFeature>
    let sort: Binding<StationSort>

    var body: some View {
        VStack(spacing: Spacing.s4) {
            fuelSegment
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s3) {
                    selfToggle
                    radiusStepper
                    sortPill(.price)
                    sortPill(.distance)
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.top, Spacing.s5)
        .padding(.bottom, Spacing.s3)
        .background(
            LinearGradient(
                stops: [
                    .init(color: Color(.surface).opacity(0), location: 0),
                    .init(color: Color(.surface).opacity(0.86), location: 0.28),
                    .init(color: Color(.surface), location: 0.55)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Combustible (segmentado scrollable)

    private var fuelSegment: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(FuelType.selectable, id: \.self) { fuel in
                    let active = store.fuel == fuel
                    Button {
                        $store.fuel.wrappedValue = fuel
                    } label: {
                        Text(fuel.label)
                            .font(.fmSubheadline.weight(.semibold))
                            .foregroundStyle(active ? Color(.brandPrimary) : Color(.textSecondary))
                            .padding(.horizontal, Spacing.s4)
                            .frame(minHeight: 38)
                            .background {
                                if active {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(Color(.surfaceElevated))
                                        .elevation(.e1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(active ? [.isSelected] : [])
                }
            }
            .padding(3)
        }
        .background(Color(.surfaceTertiary), in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    // MARK: - Self service (toggle)

    private var selfToggle: some View {
        Button {
            $store.selfOnly.wrappedValue.toggle()
        } label: {
            HStack(spacing: Spacing.s3) {
                Capsule()
                    .fill(store.selfOnly ? Color(.success) : Color(.separatorStrong))
                    .frame(width: 36, height: 22)
                    .overlay(alignment: store.selfOnly ? .trailing : .leading) {
                        Circle().fill(.white).frame(width: 18, height: 18)
                            .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                            .padding(2)
                    }
                Text("Self").font(.fmSubheadline.weight(.semibold)).foregroundStyle(Color(.textPrimary))
            }
            .padding(.horizontal, Spacing.s4)
            .frame(height: 44)
            .background(Color(.surfaceTertiary), in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Self service"))
        .accessibilityValue(store.selfOnly ? Text("attivo") : Text("disattivo"))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Filtra solo le stazioni self-service"))
    }

    // MARK: - Radio (stepper)

    private var radiusStepper: some View {
        HStack(spacing: 0) {
            stepButton(systemName: "minus", enabled: canStep(-1)) { stepRadius(-1) }
            Text("\(Int(store.radiusKm)) km")
                .font(.fmSubheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color(.textPrimary))
                .frame(minWidth: 56)
            stepButton(systemName: "plus", enabled: canStep(1)) { stepRadius(1) }
        }
        .frame(height: 44)
        .background(Color(.surfaceTertiary), in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Raggio di ricerca"))
        .accessibilityValue(Text("\(Int(store.radiusKm)) km"))
    }

    private func stepButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(enabled ? Color(.brandTint) : Color(.textTertiary))
                .frame(width: 40, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Orden (pills)

    private func sortPill(_ option: StationSort) -> some View {
        let active = sort.wrappedValue == option
        return Button {
            sort.wrappedValue = option
        } label: {
            HStack(spacing: Spacing.s2) {
                Image(systemName: option == .price ? "arrow.up.arrow.down" : "location.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text(option.label).font(.fmFootnote.weight(.semibold))
            }
            .foregroundStyle(active ? Color(.brandPrimary) : Color(.textPrimary))
            .padding(.horizontal, Spacing.s4)
            .frame(height: 44)
            .background(active ? Color(.brandSurface) : Color(.surfaceTertiary), in: Capsule())
            .overlay {
                if active { Capsule().strokeBorder(Color(.brandPrimary).opacity(0.3)) }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }

    // MARK: - Helpers de radio

    private func canStep(_ dir: Int) -> Bool {
        guard let idx = RadiusOption.all.firstIndex(of: store.radiusKm) else { return true }
        return RadiusOption.all.indices.contains(idx + dir)
    }

    private func stepRadius(_ dir: Int) {
        let opts = RadiusOption.all
        guard let idx = opts.firstIndex(of: store.radiusKm) else {
            $store.radiusKm.wrappedValue = opts.first ?? 5
            return
        }
        let next = idx + dir
        guard opts.indices.contains(next) else { return }
        $store.radiusKm.wrappedValue = opts[next]
    }
}

#Preview {
    ZStack {
        Color(.surfaceSecondary)
        VStack {
            Spacer()
            FiltersView(
                store: Store(initialState: FiltersFeature.State()) { FiltersFeature() },
                sort: .constant(.price)
            )
        }
    }
    .ignoresSafeArea()
}
