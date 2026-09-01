//
//  AdClient.swift
//  FuelMap
//
//  Created on 05/06/2026.
//

import AppTrackingTransparency
import ComposableArchitecture
@preconcurrency import GoogleMobileAds
import UIKit
@preconcurrency import UserMessagingPlatform

/// Integración de anuncios (AdMob) + consentimiento (RFC §6.4).
struct AdClient: Sendable {
    /// Inicializa el SDK de Google Mobile Ads.
    var start: @Sendable () async -> Void
    /// Flujo de consentimiento: UMP (GDPR, obligatorio UE) y luego ATT.
    var requestConsent: @Sendable () async -> Void
    /// Ad unit del banner del mapa.
    var bannerAdUnitID: @Sendable () -> String
    /// Ad unit del banner de la card de detalle (unidad propia para reporting).
    var detailAdUnitID: @Sendable () -> String
}

extension AdClient {
    /// Ad unit de banner de TEST de Google (no requiere cuenta AdMob). Fallback si
    /// el Info.plist no trae la clave (no debería pasar; ver `project.yml`).
    static let testBannerUnitID = "ca-app-pub-3940256099942544/2934735716"

    // MARK: - IDs por configuración (RELEASE-001 F2)
    //
    // Única fuente de verdad en `project.yml` (`GAD_BANNER_UNIT_ID`/
    // `GAD_DETAIL_UNIT_ID` por config → `FuelMapBannerAdUnitID`/`FuelMapDetailAdUnitID`
    // en Info.plist). Antes había un `#if DEBUG` aquí *además* del build setting de
    // `GADApplicationIdentifier` — dos interruptores para la misma decisión que
    // rompían de forma asimétrica en cuanto se añadiera una tercera config (p. ej.
    // Beta): unidades reales bajo un App ID de test, sin fill e invisible desde
    // Debug (review RELEASE-001 F1-F2, A-4).

    static var mapBannerUnitID: String {
        Bundle.main.object(forInfoDictionaryKey: "FuelMapBannerAdUnitID") as? String ?? testBannerUnitID
    }

    static var detailBannerUnitID: String {
        Bundle.main.object(forInfoDictionaryKey: "FuelMapDetailAdUnitID") as? String ?? testBannerUnitID
    }
}

// MARK: - Dependency

extension AdClient: DependencyKey {
    static let liveValue = AdClient(
        start: { await AdSDK.start() },
        requestConsent: { await AdConsentCoordinator.requestConsentThenTracking() },
        // Unidad distinta por placement (mapa / detalle) para separar el reporting.
        bannerAdUnitID: { AdClient.mapBannerUnitID },
        detailAdUnitID: { AdClient.detailBannerUnitID }
    )

    static let testValue = AdClient(
        start: {},
        requestConsent: {},
        bannerAdUnitID: { "" },
        detailAdUnitID: { "" }
    )

    static let previewValue = testValue
}

extension DependencyValues {
    var adClient: AdClient {
        get { self[AdClient.self] }
        set { self[AdClient.self] = newValue }
    }
}

// MARK: - SDK start

private enum AdSDK {
    static func start() async {
        _ = await GADMobileAds.sharedInstance().start()
    }
}

// MARK: - Consent (UMP) + App Tracking Transparency

enum AdConsentCoordinator {
    static func requestConsentThenTracking() async {
        await requestUMPConsent()
        await requestTracking()
    }

    @MainActor
    private static func requestUMPConsent() async {
        do {
            try await UMPConsentInformation.sharedInstance
                .requestConsentInfoUpdate(with: UMPRequestParameters())
            try await UMPConsentForm.loadAndPresentIfRequired(from: topViewController())
        } catch {
            // Consentimiento no disponible/error: seguir sin bloquear (ads no personalizados).
        }
    }

    private static func requestTracking() async {
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    /// Controlador visible más arriba, para presentar el formulario de consentimiento.
    @MainActor
    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
