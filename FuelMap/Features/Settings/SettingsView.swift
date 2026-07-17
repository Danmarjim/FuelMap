//
//  SettingsView.swift
//  FuelMap
//
//  Created on 17/07/2026.
//

import SwiftUI

/// Hoja de informazioni/impostazioni (PREMIUM-001 §P4).
///
/// Vista plana con callbacks, como `StationListView`/`FavoritesView`: no tiene lógica
/// propia. Aloja la entrada al paywall y la atribución IODL 2.0 de los datos del MIMIT.
///
/// El CTA premium vive aquí y no junto al banner: la política de AdMob penaliza la UI
/// adyacente al anuncio que induzca clics accidentales.
struct SettingsView: View {
    let isPremium: Bool
    let onPremiumTapped: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Informazioni", onClose: onClose)

            ScrollView {
                VStack(spacing: Spacing.s5) {
                    if isPremium {
                        premiumActiveCard
                    } else {
                        premiumCTA
                    }
                    attribution
                    version
                }
                .padding(.horizontal, Spacing.s5)
                .padding(.top, Spacing.s2)
                .padding(.bottom, Spacing.s6)
            }
        }
        .background(Color(.surface))
    }

    // MARK: - Premium

    private var premiumCTA: some View {
        Button(action: onPremiumTapped) {
            HStack(spacing: Spacing.s4) {
                Image(systemName: "sparkles")
                    .font(.fmTitle3)
                    .foregroundStyle(Color(.onBrand))
                    .frame(width: 44, height: 44)
                    .background(Color(.brandPrimaryFill), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.s1) {
                    Text("Rimuovi la pubblicità")
                        .font(.fmHeadline)
                        .foregroundStyle(Color(.textPrimary))
                    Text("Pagamento unico, nessun abbonamento")
                        .font(.fmFootnote)
                        .foregroundStyle(Color(.textSecondary))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.fmFootnote.weight(.semibold))
                    .foregroundStyle(Color(.textTertiary))
                    .accessibilityHidden(true)
            }
            .padding(Spacing.s4)
            .background(
                Color(.brandSurface),
                in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private var premiumActiveCard: some View {
        HStack(spacing: Spacing.s4) {
            Image(systemName: "checkmark.seal.fill")
                .font(.fmTitle3)
                .foregroundStyle(Color(.success))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text("Versione senza pubblicità attiva")
                    .font(.fmHeadline)
                    .foregroundStyle(Color(.textPrimary))
                Text("Grazie per il supporto.")
                    .font(.fmFootnote)
                    .foregroundStyle(Color(.textSecondary))
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.s4)
        .background(
            Color(.surfaceSecondary),
            in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
        )
    }

    // MARK: - Attribuzione (IODL 2.0)

    private var attribution: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text("Origine dei dati")
                .font(.fmFootnote.weight(.semibold))
                .foregroundStyle(Color(.textSecondary))
            Text("Prezzi e distributori dal MIMIT — Ministero delle Imprese e del Made in Italy, "
                 + "distribuiti con licenza IODL 2.0. Aggiornamento giornaliero.")
                .font(.fmFootnote)
                .foregroundStyle(Color(.textTertiary))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.s4)
        .background(
            Color(.surfaceSecondary),
            in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
        )
    }

    private var version: some View {
        Text(verbatim: "FuelMap \(Bundle.main.appVersion)")
            .font(.fmCaption)
            .foregroundStyle(Color(.textTertiary))
            .frame(maxWidth: .infinity)
    }
}

extension Bundle {
    /// Versión de marketing + build (`1.0.0 (12)`), para la hoja de informazioni.
    var appVersion: String {
        let short = infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }
}

#Preview("Gratuito") {
    SettingsView(isPremium: false, onPremiumTapped: {}, onClose: {})
}

#Preview("Premium") {
    SettingsView(isPremium: true, onPremiumTapped: {}, onClose: {})
}
