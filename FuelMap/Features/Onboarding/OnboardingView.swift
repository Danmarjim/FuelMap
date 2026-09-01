//
//  OnboardingView.swift
//  FuelMap
//
//  Created on 01/09/2026.
//

import ComposableArchitecture
import SwiftUI

/// Onboarding de primer lanzamiento: 2 pantallas, siempre saltables
/// (RELEASE-001 Fase 1). Navegación por swipe (`TabView` paginado) con control de
/// página animado; el botón "Continua" es un atajo al mismo gesto.
struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingFeature>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            skipHeader
            TabView(selection: pageBinding) {
                pageContent(
                    symbol: "fuelpump.fill",
                    title: "Trova il distributore più conveniente",
                    subtitle: """
                        Prezzi ufficiali del MIMIT, aggiornati ogni giorno: te li mostriamo \
                        sulla mappa, senza dover cercare.
                        """
                )
                .tag(OnboardingFeature.Page.welcome)

                pageContent(
                    symbol: "location.fill",
                    title: "Attiva la posizione",
                    subtitle: "Ci serve per mostrarti i distributori più vicini a te e ordinarli per distanza."
                )
                .tag(OnboardingFeature.Page.location)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            pageControl
            footer
        }
        .background(Color(.surface))
    }

    private var pageBinding: Binding<OnboardingFeature.Page> {
        Binding(
            get: { store.page },
            set: { store.send(.pageChanged($0)) }
        )
    }

    // MARK: - Header

    @ViewBuilder
    private var skipHeader: some View {
        HStack {
            Spacer()
            // Renderizado condicional, no `.opacity(0)` + `.disabled(true)`: eso deja
            // el botón en el árbol de accesibilidad y VoiceOver lo anuncia como
            // "Salta, atenuado" en la página 2, donde no hace nada (review M-6). No
            // se muestra en la página 2 porque ahí ya no aporta nada nuevo: "Attiva
            // posizione" hace exactamente lo mismo (pide el permiso y termina).
            if store.page == .welcome {
                Button { store.send(.skipTapped) } label: {
                    Text("Salta")
                        .font(.fmSubheadline.weight(.semibold))
                        .foregroundStyle(Color(.textSecondary))
                        .frame(minHeight: 44)
                }
            }
        }
        // Altura fija: sin el botón en la página 2, la cabecera no debe encogerse
        // (mismo motivo que antes tenía `.opacity(0)`, ya sin el coste de accesibilidad).
        .frame(height: 44)
        .padding(.horizontal, Spacing.s5)
    }

    // MARK: - Control de página

    private var pageControl: some View {
        HStack(spacing: Spacing.s3) {
            ForEach(OnboardingFeature.Page.allCases, id: \.self) { page in
                Capsule()
                    // NO `Color(.separator)` para el punto inactivo: contra `surface`
                    // da 1,40:1, muy por debajo del 3:1 que WCAG pide a un componente
                    // de UI no textual. `textTertiary` sí pasa, 3,13:1 (review M-5).
                    .fill(page == store.page ? Color(.brandPrimaryFill) : Color(.textTertiary))
                    .frame(width: page == store.page ? 20 : 6, height: 6)
            }
        }
        .padding(.vertical, Spacing.s5)
        .animation(reduceMotion ? nil : .spring(duration: 0.3), value: store.page)
        // NO `.accessibilityHidden(true)`: es la navegación principal de un `TabView`
        // por swipe — sin esto, VoiceOver no tiene ninguna noción de en qué página
        // está ni de cuántas hay (review M-5).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Pagina", comment: "Indicador de página del onboarding"))
        .accessibilityValue(pageAccessibilityValue)
    }

    /// Valores literales (no interpolados) para no depender de cómo SwiftUI resuelve
    /// el placeholder de un `Text` con enteros interpolados en la clave — con solo 2
    /// páginas, enumerar es más simple y verificable que generalizar.
    private var pageAccessibilityValue: Text {
        switch store.page {
        case .welcome: return Text("1 di 2", comment: "Indicador de página del onboarding")
        case .location: return Text("2 di 2", comment: "Indicador de página del onboarding")
        }
    }

    // MARK: - Página

    private func pageContent(
        symbol: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey
    ) -> some View {
        // `ScrollView` en vez de `Spacer()`+`Spacer()`: en tamaños de Dynamic Type de
        // accesibilidad (AX3+) el icono+título+subtítulo no cabían en una pantalla
        // pequeña y el `TabView` no permitía scroll, así que el texto se recortaba
        // sin recurso (review RELEASE-001 F1-F2, A-5). A tamaño normal queda arriba
        // con aire en vez de perfectamente centrado — trade-off aceptado.
        ScrollView {
            VStack(spacing: Spacing.s6) {
                Image(systemName: symbol)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Color(.onBrand))
                    .frame(width: 96, height: 96)
                    .background(Color(.brandPrimaryFill), in: Circle())
                    .accessibilityHidden(true)

                Text(title)
                    .font(.fmTitle1)
                    .foregroundStyle(Color(.textPrimary))
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.fmBody)
                    .foregroundStyle(Color(.textSecondary))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.s7)
            .padding(.vertical, Spacing.s8)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Footer (CTA)

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: Spacing.s3) {
            switch store.page {
            case .welcome:
                primaryButton("Continua") { store.send(.pageChanged(.location)) }

            case .location:
                primaryButton("Attiva posizione") { store.send(.enableLocationTapped) }
            }
        }
        .padding(.horizontal, Spacing.s5)
        .padding(.bottom, Spacing.s6)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: store.page)
    }

    private func primaryButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.fmHeadline.weight(.semibold))
                .foregroundStyle(Color(.onBrand))
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    Color(.brandPrimaryFill),
                    in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                )
        }
    }
}

#Preview("Bienvenida") {
    OnboardingView(
        store: Store(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }
    )
}

#Preview("Ubicación") {
    OnboardingView(
        store: Store(initialState: OnboardingFeature.State(page: .location)) {
            OnboardingFeature()
        }
    )
}
