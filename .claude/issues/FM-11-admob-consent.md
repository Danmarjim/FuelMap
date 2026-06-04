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

## Acceptance Criteria
- [ ] En primer arranque aparece el form UMP (cuando aplica) y luego el prompt ATT.
- [ ] Banner adaptativo visible debajo del mapa sin solapar.
- [ ] Ads no personalizados si el usuario rechaza tracking.
- [ ] IDs de test en debug, reales en release.
- [ ] Tests pass.

## References
- RFC: §6.4, §3.3
- AdMob ATT/UMP: https://developers.google.com/admob/ios/privacy/idfa
