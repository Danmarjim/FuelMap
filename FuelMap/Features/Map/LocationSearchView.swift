//
//  LocationSearchView.swift
//  FuelMap
//
//  Created on 01/09/2026.
//

import SwiftUI

/// Búsqueda manual de ciudad/dirección para centrar el mapa donde interese — sin
/// permiso de ubicación, o simplemente para mirar otra zona (RELEASE-001).
///
/// La presentación (`isPresented`) la posee `MapFeature`, no un `@Environment(\.dismiss)`
/// local: el cierre en éxito es explícito desde el reducer, no inferido de que
/// `isSearching` y `errorMessage` cambien en el mismo frame (review RELEASE-001 F1-F2, M-1).
struct LocationSearchView: View {
    @State private var query = ""
    @FocusState private var isFocused: Bool

    let isSearching: Bool
    let errorMessage: String?
    let onSubmit: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Cerca una città", onClose: onClose)

            // `ScrollView`: en tamaños de Dynamic Type de accesibilidad el campo +
            // botón + mensaje de error no caben en una pantalla pequeña sin desbordar
            // (review RELEASE-001 F1-F2, A-5).
            ScrollView {
                VStack(spacing: Spacing.s4) {
                    HStack(spacing: Spacing.s3) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color(.textSecondary))
                            .accessibilityHidden(true)
                        TextField("Es. Milano, Barcellona…", text: $query)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .focused($isFocused)
                            .submitLabel(.search)
                            .onSubmit { submit() }
                    }
                    .padding(Spacing.s4)
                    .background(
                        Color(.surfaceSecondary),
                        in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    )

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.fmFootnote)
                            .foregroundStyle(Color(.error))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(action: submit) {
                        Group {
                            if isSearching {
                                ProgressView().tint(Color(.onBrand))
                            } else {
                                Text("Cerca")
                            }
                        }
                        .font(.fmHeadline.weight(.semibold))
                        .foregroundStyle(Color(.onBrand))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(
                            Color(.brandPrimaryFill),
                            in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        )
                    }
                    // Sin esto, mientras `isSearching` el label es un `ProgressView`
                    // desnudo y VoiceOver lee "botón" sin nombre (review M-4).
                    .accessibilityLabel(Text("Cerca"))
                    .disabled(isSearching || query.nilIfEmpty == nil)
                }
                .padding(Spacing.s5)
            }
        }
        .background(Color(.surface))
        .onAppear { isFocused = true }
    }

    private func submit() {
        guard query.nilIfEmpty != nil else { return }
        onSubmit(query)
    }
}

#Preview("Vacío") {
    LocationSearchView(isSearching: false, errorMessage: nil, onSubmit: { _ in }, onClose: {})
}

#Preview("Sin resultados") {
    LocationSearchView(
        isSearching: false,
        errorMessage: "Nessun risultato per questa ricerca.",
        onSubmit: { _ in },
        onClose: {}
    )
}
