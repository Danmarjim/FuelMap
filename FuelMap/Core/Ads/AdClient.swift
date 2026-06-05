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
    /// Ad unit del banner (TEST por ahora; el real llega en FM-14).
    var bannerAdUnitID: @Sendable () -> String
}

extension AdClient {
    /// Ad unit de banner de TEST de Google (no requiere cuenta AdMob).
    static let testBannerUnitID = "ca-app-pub-3940256099942544/2934735716"
}

// MARK: - Dependency

extension AdClient: DependencyKey {
    static let liveValue = AdClient(
        start: { await AdSDK.start() },
        requestConsent: { await AdConsentCoordinator.requestConsentThenTracking() },
        // Pendiente (FM-14): ad unit real en release; TEST en debug.
        bannerAdUnitID: { AdClient.testBannerUnitID }
    )

    static let testValue = AdClient(
        start: {},
        requestConsent: {},
        bannerAdUnitID: { "" }
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
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            GADMobileAds.sharedInstance().start { _ in continuation.resume() }
        }
    }
}

// MARK: - Consent (UMP) + App Tracking Transparency

enum AdConsentCoordinator {
    static func requestConsentThenTracking() async {
        await requestUMPConsent()
        await requestTracking()
    }

    private static func requestUMPConsent() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            UMPConsentInformation.sharedInstance
                .requestConsentInfoUpdate(with: UMPRequestParameters()) { _ in
                    Task { @MainActor in
                        UMPConsentForm.loadAndPresentIfRequired(from: topViewController()) { _ in
                            continuation.resume()
                        }
                    }
                }
        }
    }

    private static func requestTracking() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ATTrackingManager.requestTrackingAuthorization { _ in continuation.resume() }
        }
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
