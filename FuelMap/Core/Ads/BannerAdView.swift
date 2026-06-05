//
//  BannerAdView.swift
//  FuelMap
//
//  Created on 05/06/2026.
//

@preconcurrency import GoogleMobileAds
import SwiftUI

/// Banner de AdMob (RFC §6.4). Se coloca FUERA del área del mapa (PRD F8).
struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = adUnitID
        banner.rootViewController = AdConsentCoordinator.topViewController()
        banner.load(GADRequest())
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {}
}
