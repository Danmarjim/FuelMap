//
//  StationDetailView.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import ComposableArchitecture
import SwiftUI
import UIKit

/// Detalle de estación presentado en sheet (RFC §6.2), reestilizado al design system (R4).
struct StationDetailView: View {
    let store: StoreOf<StationDetailFeature>

    @State private var showingNavOptions = false
    /// Apps de navegación instaladas (Apple Maps siempre). Se calcula una vez al
    /// aparecer (evita `canOpenURL` —I/O UIKit— en cada render del body).
    @State private var availableNavApps: [NavApp] = []

    private static func detectNavApps() -> [NavApp] {
        NavApp.allCases.filter { app in
            guard let probe = app.probeURL else { return true }
            return UIApplication.shared.canOpenURL(probe)
        }
    }

    var body: some View {
        Group {
            if let station = store.station {
                content(for: station)
            } else if let error = store.errorMessage {
                SheetEmptyState(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "Errore",
                    message: "\(error)",
                    tint: Color(.error),
                    tintSurface: Color(.errorSurface)
                )
                .frame(maxHeight: .infinity)
            } else {
                ProgressView("Caricamento…").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(.surfaceElevated))
        .onAppear {
            store.send(.onAppear)
            if availableNavApps.isEmpty { availableNavApps = Self.detectNavApps() }
        }
    }

    @ViewBuilder
    private func content(for station: Station) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero(station)
                sectionHeader(station)
                pricesContent(for: station)
                addressRow(station)
                cta
                adSection
            }
        }
        .confirmationDialog("Indicazioni", isPresented: $showingNavOptions, titleVisibility: .hidden) {
            ForEach(availableNavApps, id: \.self) { app in
                Button(app.label) { store.send(.navigate(app)) }
            }
        }
    }

    // MARK: - Hero

    private func hero(_ station: Station) -> some View {
        HStack(alignment: .top, spacing: Spacing.s4) {
            BrandBadge(brand: BrandStyle.from(station.brand), size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(station.name)
                    .font(.fmTitle2)
                    .foregroundStyle(Color(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)
                if let address = station.address {
                    Text(address).font(.fmSubheadline).foregroundStyle(Color(.textSecondary))
                }
            }
            Spacer(minLength: Spacing.s3)
            favoriteButton
        }
        .padding(.horizontal, Spacing.s5)
        .padding(.top, Spacing.s5)
        .padding(.bottom, Spacing.s4)
    }

    private var favoriteButton: some View {
        Button {
            store.send(.favoriteToggled)
        } label: {
            Image(systemName: store.isFavorite ? "star.fill" : "star")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(store.isFavorite ? Color(.goldInk) : Color(.textSecondary))
                .frame(width: 40, height: 40)
                .background(Color(.surfaceTertiary), in: Circle())
        }
        .accessibilityLabel(
            store.isFavorite ? Text("Rimuovi dai preferiti") : Text("Aggiungi ai preferiti")
        )
    }

    // MARK: - Precios

    private func sectionHeader(_ station: Station) -> some View {
        HStack {
            Text("Prezzi · €/L")
                .font(.fmFootnote.weight(.bold))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(Color(.textTertiary))
            Spacer()
            if let updated = latestUpdate(for: station) {
                FreshnessPill(date: updated)
            }
        }
        .padding(.horizontal, Spacing.s5)
        .padding(.vertical, Spacing.s3)
    }

    @ViewBuilder
    private func pricesContent(for station: Station) -> some View {
        let rows = variantRows(for: station)
        if rows.isEmpty {
            if store.isLoading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, Spacing.s7)
            } else {
                Text("Nessun prezzo disponibile")
                    .font(.fmSubheadline)
                    .foregroundStyle(Color(.textSecondary))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.s7)
            }
        } else {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    HairlineDivider().padding(.horizontal, Spacing.s5)
                }
                priceRow(row)
            }
        }
    }

    private func priceRow(_ row: FuelVariant) -> some View {
        let selected = row.fuel == store.selectedFuel
        let best = [row.selfPrice, row.servitoPrice].compactMap { $0 }.min()
        return HStack(alignment: .center, spacing: Spacing.s4) {
            HStack(spacing: Spacing.s3) {
                Text(row.name)
                    .font(.fmBody.weight(.semibold))
                    .foregroundStyle(Color(.textPrimary))
                    .lineLimit(1)
                if selected {
                    Text("Filtro")
                        .font(.system(size: 9.5, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Color(.brandPrimary))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.brandSurface), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
            }
            Spacer(minLength: Spacing.s3)
            HStack(spacing: Spacing.s6) {
                priceColumn("Self", row.selfPrice, isBest: row.selfPrice != nil && row.selfPrice == best)
                priceColumn("Servito", row.servitoPrice, isBest: row.servitoPrice != nil && row.servitoPrice == best)
            }
        }
        .padding(.horizontal, Spacing.s5)
        .padding(.vertical, Spacing.s4)
        .frame(minHeight: 60)
        .background(selected ? Color(.brandSurface) : Color.clear)
        .overlay(alignment: .leading) {
            if selected { Rectangle().fill(Color(.brandPrimary)).frame(width: 4) }
        }
        .accessibilityElement(children: .combine)
    }

    private func priceColumn(_ label: LocalizedStringKey, _ price: Decimal?, isBest: Bool) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(Color(.textTertiary))
            Text(price.map { $0.fuelPriceValue } ?? "—")
                .font(.fmPriceDetail)
                .foregroundStyle(isBest ? Color(.priceCheapInk) : Color(.textPrimary))
        }
    }

    // MARK: - Dirección + CTA

    @ViewBuilder
    private func addressRow(_ station: Station) -> some View {
        if let address = station.address {
            HairlineDivider().padding(.horizontal, Spacing.s5)
            Button {
                requestDirections()
            } label: {
                HStack(spacing: Spacing.s4) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(Color(.brandTint))
                        .frame(width: 22)
                    Text(address)
                        .font(.fmCallout)
                        .foregroundStyle(Color(.textPrimary))
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(.textTertiary))
                }
                .padding(.horizontal, Spacing.s5)
                .padding(.vertical, Spacing.s4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var cta: some View {
        Button {
            requestDirections()
        } label: {
            HStack(spacing: Spacing.s3) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                Text("Indicazioni")
            }
            .font(.fmHeadline)
            .foregroundStyle(Color(.onBrand))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color(.brandPrimaryFill), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
        .padding(Spacing.s5)
    }

    /// Banner de la card (monetización). Separado del CTA y etiquetado "Annuncio"
    /// para cumplir política AdMob (sin clics accidentales).
    @ViewBuilder
    private var adSection: some View {
        if !store.adUnitID.isEmpty {
            VStack(spacing: Spacing.s2) {
                Text("Annuncio")
                    .font(.fmCaption2)
                    .foregroundStyle(Color(.textTertiary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                BannerAdView(adUnitID: store.adUnitID)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.top, Spacing.s2)
            .padding(.bottom, Spacing.s6)
        }
    }

    private func requestDirections() {
        let apps = availableNavApps
        if apps.count <= 1 {
            store.send(.navigate(.appleMaps))
        } else {
            showingNavOptions = true
        }
    }

    private func variantRows(for station: Station) -> [FuelVariant] {
        FuelVariantBuilder.variants(for: station, selected: store.selectedFuel)
    }

    private func latestUpdate(for station: Station) -> Date? {
        station.prices.compactMap(\.communicatedAt).max()
    }
}

// MARK: - Data shaping

/// Una fila por producto real (`fuelRaw`), con su self/servito.
struct FuelVariant: Identifiable, Equatable {
    let id: String
    let name: String
    let fuel: FuelType
    let selfPrice: Decimal?
    let servitoPrice: Decimal?
}

/// Agrupa los precios de una estación por producto real (`fuelRaw`) y ordena el
/// combustible filtrado primero. Función pura (testeable).
enum FuelVariantBuilder {
    static func variants(for station: Station, selected: FuelType) -> [FuelVariant] {
        var order: [String] = []
        var byRaw: [String: [FuelPrice]] = [:]
        for price in station.prices {
            if byRaw[price.fuelRaw] == nil { order.append(price.fuelRaw) }
            byRaw[price.fuelRaw, default: []].append(price)
        }
        let rows = order.compactMap { raw -> FuelVariant? in
            guard let prices = byRaw[raw], let first = prices.first else { return nil }
            return FuelVariant(
                id: raw,
                name: raw,
                fuel: first.fuel,
                selfPrice: prices.first { $0.isSelf }?.price,
                servitoPrice: prices.first { !$0.isSelf }?.price
            )
        }
        // El combustible filtrado va primero; dentro, por nombre.
        return rows.sorted { lhs, rhs in
            if (lhs.fuel == selected) != (rhs.fuel == selected) { return lhs.fuel == selected }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

#Preview {
    StationDetailView(
        store: Store(
            initialState: StationDetailFeature.State(
                stationId: 1,
                station: StationFixtures.all[0]
            )
        ) {
            StationDetailFeature()
        }
    )
}
