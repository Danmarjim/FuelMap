//
//  LocationPromptOverlay.swift
//  FuelMap
//
//  Created on 01/09/2026.
//

import SwiftUI

/// Bloquea el mapa mientras no hay ningún contexto de ubicación (ni permiso
/// concedido ni ciudad buscada a mano): sin eso, el mapa muestra Roma sin relación
/// con el usuario y la app pierde buena parte de su sentido (decisión de producto,
/// LOCATION-FALLBACK-001 parte 3). Ofrece las dos salidas con el mismo peso visual,
/// no solo "dar el permiso" — la búsqueda manual es una salida igual de válida.
struct LocationPromptOverlay: View {
    let onEnableLocation: () -> Void
    let onSearchCity: () -> Void

    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .ignoresSafeArea()
            .overlay { card }
            // El contenido de debajo (mapa, controles, filtros) se oculta desde
            // `MapView` con `.accessibilityHidden`; esto marca la propia tarjeta como
            // el único destino del foco de VoiceOver mientras está presente — sin
            // esto, un `.overlay` bloquea toques y píxeles pero no el árbol de
            // accesibilidad (review RELEASE-001 F1-F2, C-3).
            .accessibilityAddTraits(.isModal)
    }

    private var card: some View {
        ScrollView {
            VStack(spacing: Spacing.s5) {
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Color(.onBrand))
                    .frame(width: 88, height: 88)
                    .background(Color(.brandPrimaryFill), in: Circle())
                    .accessibilityHidden(true)

                VStack(spacing: Spacing.s3) {
                    Text("Attiva la posizione per continuare")
                        .font(.fmTitle3)
                        .foregroundStyle(Color(.textPrimary))
                        .multilineTextAlignment(.center)

                    Text("""
                        FuelMap ti mostra i distributori più vicini a te. \
                        Senza la posizione, puoi comunque cercare una città.
                        """)
                        .font(.fmSubheadline)
                        .foregroundStyle(Color(.textSecondary))
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: Spacing.s3) {
                    Button(action: onEnableLocation) {
                        Text("Attiva posizione")
                            .font(.fmHeadline.weight(.semibold))
                            .foregroundStyle(Color(.onBrand))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(
                                Color(.brandPrimaryFill),
                                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            )
                    }

                    Button(action: onSearchCity) {
                        Text("Cerca una città")
                            .font(.fmHeadline.weight(.semibold))
                            // NO `brandTint`: en modo claro es exactamente el mismo
                            // #0091FF que `brandPrimary` (son el mismo colorset), y
                            // sobre `surfaceSecondary` da 2,92:1 — no pasa WCAG AA
                            // (4,5:1) para texto de 17pt semibold. `brandPrimaryPressed`
                            // (#005BB8) sí pasa, 5,93:1 (review RELEASE-001 F1-F2, A-3).
                            .foregroundStyle(Color(.brandPrimaryPressed))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(
                                Color(.surfaceSecondary),
                                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            )
                    }
                }
            }
            .padding(Spacing.s6)
        }
        .background(Color(.surfaceElevated), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .elevation(.e3, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .padding(.horizontal, Spacing.s7)
    }
}

#Preview {
    ZStack {
        Color(.surfaceSecondary)
        LocationPromptOverlay(onEnableLocation: {}, onSearchCity: {})
    }
    .ignoresSafeArea()
}
