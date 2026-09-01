//
//  PaywallView.swift
//  FuelMap
//
//  Created on 17/07/2026.
//

import ComposableArchitecture
import SwiftUI

/// Enlaces legales de la app.
enum LegalURLs {
    /// EULA estándar de Apple: válido cuando la app no aporta uno propio.
    static let eula = URL(
        string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    )! // swiftlint:disable:this force_unwrapping

    /// GitHub Pages desde `/docs` (it/es/en en una sola página) — RELEASE-001 F2.
    static let privacyPolicy = URL(
        string: "https://danmarjim.github.io/FuelMap/privacy-policy.html"
    )! // swiftlint:disable:this force_unwrapping
}

/// Fila de enlaces legales — antes duplicada en `PaywallView`/`SettingsView` con
/// orden y estilo distintos (Apple/App Review ven las dos); review RELEASE-001
/// F1-F2, reuso #6.
struct LegalLinksRow: View {
    var body: some View {
        HStack(spacing: Spacing.s4) {
            Link(destination: LegalURLs.privacyPolicy) {
                Text("Privacy")
            }
            Link(destination: LegalURLs.eula) {
                Text("Condizioni d'uso")
            }
        }
        .font(.fmCaption)
        .foregroundStyle(Color(.textTertiary))
    }
}

/// Paywall del pago único "senza pubblicità" (PREMIUM-001 §P4).
struct PaywallView: View {
    @Bindable var store: StoreOf<PaywallFeature>

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "FuelMap senza pubblicità") { store.send(.closeTapped) }

            ScrollView {
                VStack(spacing: Spacing.s6) {
                    hero
                    benefits
                    if let message = store.errorMessage {
                        noticeRow(message, isError: true)
                    }
                    if store.isPending {
                        noticeRow(
                            String(localized: "Acquisto in attesa di approvazione."),
                            isError: false
                        )
                    }
                }
                .padding(.horizontal, Spacing.s5)
                .padding(.top, Spacing.s4)
                .padding(.bottom, Spacing.s6)
            }

            footer
        }
        .background(Color(.surface))
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Secciones

    private var hero: some View {
        VStack(spacing: Spacing.s4) {
            Image(systemName: "fuelpump.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color(.onBrand))
                .frame(width: 88, height: 88)
                .background(Color(.brandPrimaryFill), in: Circle())
                .accessibilityHidden(true)

            Text("Un pagamento unico, per sempre")
                .font(.fmTitle2)
                .foregroundStyle(Color(.textPrimary))
                .multilineTextAlignment(.center)

            Text("Niente abbonamenti: paghi una volta e la pubblicità sparisce da tutta l'app.")
                .font(.fmSubheadline)
                .foregroundStyle(Color(.textSecondary))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            benefitRow("rectangle.slash", "Nessun banner pubblicitario")
            benefitRow("hand.raised.fill", "Nessuna richiesta di tracciamento")
            benefitRow("heart.fill", "Sostieni lo sviluppo dell'app")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.s5)
        .background(
            Color(.surfaceSecondary),
            in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
        )
    }

    private func benefitRow(_ symbol: String, _ title: LocalizedStringKey) -> some View {
        HStack(spacing: Spacing.s4) {
            Image(systemName: symbol)
                .font(.fmHeadline)
                .foregroundStyle(Color(.brandTint))
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(title)
                .font(.fmBody)
                .foregroundStyle(Color(.textPrimary))
            Spacer(minLength: 0)
        }
    }

    private func noticeRow(_ message: String, isError: Bool) -> some View {
        HStack(spacing: Spacing.s3) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "clock.fill")
                .foregroundStyle(Color(isError ? .error : .warning))
            Text(message)
                .font(.fmFootnote)
                .foregroundStyle(Color(.textPrimary))
            Spacer(minLength: 0)
        }
        .padding(Spacing.s4)
        .background(
            Color(isError ? .errorSurface : .warningSurface),
            in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
        )
    }

    // MARK: - Footer (CTA + legal)

    private var footer: some View {
        VStack(spacing: Spacing.s3) {
            Button { store.send(.purchaseTapped) } label: {
                Group {
                    if store.isPurchasing {
                        ProgressView().tint(Color(.onBrand))
                    } else {
                        Text(ctaTitle)
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
            .disabled(store.isBusy || store.product == nil)
            .opacity(store.product == nil ? 0.5 : 1)

            // Restore: obligatorio para un no-consumible en la revisión de Apple.
            Button { store.send(.restoreTapped) } label: {
                Group {
                    if store.isRestoring {
                        ProgressView()
                    } else {
                        Text("Ripristina acquisti")
                    }
                }
                .font(.fmFootnote.weight(.semibold))
                .foregroundStyle(Color(.brandTint))
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .disabled(store.isBusy)

            LegalLinksRow()
        }
        .padding(.horizontal, Spacing.s5)
        .padding(.top, Spacing.s3)
        .padding(.bottom, Spacing.s5)
        .background(Color(.surfaceElevated))
        .overlay(alignment: .top) {
            HairlineDivider()
        }
    }

    /// El precio siempre viene de StoreKit (`displayPrice`): nunca se codifica en la app.
    private var ctaTitle: LocalizedStringKey {
        if let price = store.product?.displayPrice {
            return "Rimuovi la pubblicità — \(price)"
        }
        return store.isLoading ? "Caricamento…" : "Non disponibile"
    }
}

#Preview("Disponibile") {
    PaywallView(
        store: Store(initialState: PaywallFeature.State()) {
            PaywallFeature()
        } withDependencies: {
            $0.purchaseClient = .mock()
        }
    )
}

#Preview("Errore") {
    PaywallView(
        store: Store(initialState: PaywallFeature.State()) {
            PaywallFeature()
        } withDependencies: {
            $0.purchaseClient.premiumProduct = { throw PurchaseError.productUnavailable }
        }
    )
}
