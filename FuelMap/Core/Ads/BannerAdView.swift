//
//  BannerAdView.swift
//  FuelMap
//
//  Created on 05/06/2026.
//

@preconcurrency import GoogleMobileAds
import SwiftUI
import UIKit

/// Banner de AdMob (RFC §6.4). Se coloca FUERA del área del mapa (PRD F8).
struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> GADBannerView {
        let width = AdConsentCoordinator.topViewController()?.view.bounds.width
            ?? UIScreen.main.bounds.width
        let banner = GADBannerView(
            adSize: GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width)
        )
        banner.adUnitID = adUnitID
        banner.rootViewController = AdConsentCoordinator.topViewController()
        banner.load(GADRequest())
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
        // Reacciona a cambios de ad unit (p. ej. test→real) o de root VC.
        if uiView.adUnitID != adUnitID {
            uiView.adUnitID = adUnitID
            uiView.load(GADRequest())
        }
        if uiView.rootViewController == nil {
            uiView.rootViewController = AdConsentCoordinator.topViewController()
        }
    }
}
