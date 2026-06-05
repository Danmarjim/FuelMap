# FM-11: AdClient — AdMob banner + UMP (GDPR) + ATT

> Derivado de RFC-001 §6.4, §3.3. Self-contained.

## Description
Integrar AdMob: banner adaptativo anclado debajo del mapa, con flujo de consentimiento Google UMP (GDPR, obligatorio en Italia/UE) seguido del prompt ATT, gestionados como `@Dependency`.

Complexity: M
Dependencies: FM-1, FM-7

## Files to Modify
- `Core/Ads/AdClient.swift` (nuevo) — dependencia (consent + bannerAdUnitID).
- `Core/Ads/BannerAdView.swift` (nuevo) — `UIViewRepresentable` del banner.
- `App/FuelMapApp.swift` / onboarding — disparar consentimiento al arranque.
- `Info.plist` — `GADApplicationIdentifier`, `NSUserTrackingUsageDescription`, `SKAdNetworkItems`.

## Technical Specification (from RFC)
**Source:** RFC §6.4, §3.3.

```swift
struct AdClient: Sendable {
    var requestConsent: @Sendable () async -> Void   // UMP (GDPR) + ATT
    var bannerAdUnitID: @Sendable () -> String
}
```

Orden de consentimiento (onboarding):
1. Google UMP `requestConsentInfoUpdate` + presentar form si requerido (GDPR).
2. Tras UMP, ATT `requestTrackingAuthorization`.
3. Inicializar GMA SDK; servir ads no personalizados como fallback si el usuario rechaza.

Banner: adaptativo, en `VStack` **debajo** del mapa, nunca solapando (RFC §6.4, PRD F8).

Usar IDs de test de AdMob en desarrollo; los reales en release config.

## What NOT to Do
- Do NOT mostrar el banner solapando el mapa.
- Do NOT pedir ATT antes del form UMP.
- Do NOT usar interstitials/rewarded en v1 (solo banner).
- Do NOT hardcodear el ad unit ID de producción en el repo.

## Tests to Add
```swift
@Test func adClient_requestConsent_runsUMPThenATT()   // con doubles
```

Mock/stub strategy: `testValue` de `AdClient` que registra el orden de llamadas; la UI de banner se valida manualmente (no testeable en unidad).

## Status: DONE (2026-06-05) — IDs de TEST; producción → FM-14

> GoogleMobileAds 11.13.0 + UMP 2.7.0 (API v11 `GAD*`). Info.plist explícito (XcodeGen `info`, gitignored) con `GADApplicationIdentifier` + `NSUserTrackingUsageDescription`. Banner estándar (`GADAdSizeBanner`) bajo el mapa; adaptativo = posible mejora. Verificado en simulador: form UMP (test) + prompt ubicación + banner test ("Test mode/Nice job!").

## Acceptance Criteria
- [x] En primer arranque aparece el form UMP (test) y el flujo continúa a ATT.
- [x] Banner visible **debajo del mapa** sin solapar (AppView VStack: mapa + banner).
- [~] Ads no personalizados si se rechaza: lo gestiona UMP/AdMob según consentimiento (config real en FM-14).
- [~] IDs: TEST en debug y release por ahora → IDs reales en **FM-14**.
- [x] Tests pass: +1 (onAppear consent→start); 39 totales. SwiftLint 0.

## Deuda → FM-14
- Ad unit + `GADApplicationIdentifier` reales; `SKAdNetworkItems`; privacy labels; l10n del Info.plist.

## References
- RFC: §6.4, §3.3
- AdMob ATT/UMP: https://developers.google.com/admob/ios/privacy/idfa
