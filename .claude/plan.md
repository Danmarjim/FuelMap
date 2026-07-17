# Plan: PREMIUM-001 — Capa premium (pago único, sin anuncios) con StoreKit 2

> **Objetivo (Goal).** Añadir una compra **no-consumible de pago único** que elimina los
> anuncios de toda la app. Implementación con **StoreKit 2 directo** envuelto en un
> `PurchaseClient` (`@Dependency`), sin dependencias de terceros. El usuario premium no
> ve banners **ni el formulario UMP ni el prompt de ATT**: sin ads no hay base legal que
> pedir ni tracking que consentir.

> **Decisiones tomadas con el usuario (2026-07-17).**
> 1. **StoreKit 2 directo, no RevenueCat.** RevenueCat resuelve suscripciones
>    (renovaciones, churn, grace periods, entitlements cross-platform); para un único
>    no-consumible aporta un dashboard a cambio de un SDK, una cuenta y ~1% de fee.
>    `Transaction.currentEntitlements` + `Transaction.updates` cubren compra, restore
>    entre dispositivos, family sharing y refunds sin servidor propio.
> 2. **Favoritos siguen gratis e ilimitados.** Descartado capar favoritos: es el gancho
>    de retención, y la retención *es* el ingreso publicitario del tramo free. Además es
>    expectativa de categoría (Google Maps, Waze, Prezzi Benzina lo dan gratis) y las
>    reseñas son el canal de adquisición de una app gratis.
> 3. **El pack v1 es solo "quitar los anuncios".** No se infla con features para
>    justificar precio. Economía: eCPM de banner en Italia ~€1–4 → un usuario que abre
>    4×/mes deja del orden de €0,30–0,50/año; un pago único de ~€3,99 equivale a ~10 años
>    de ese usuario, cobrados hoy.

---

## Contexto (Context)

- App **no publicada** (FM-14 pendiente): no hay usuarios a los que quitar nada, así que
  el diseño no arrastra deuda de migración.
- Ads ya integrados: `Core/Ads/AdClient.swift` (`start` / `requestConsent` UMP→ATT /
  `bannerAdUnitID` / `detailAdUnitID`) + `Core/Ads/BannerAdView.swift`.
- **Dos placements**: `AppView` (banner bajo el mapa) y `StationDetailView:253`.
- Ambos ya se ocultan solos con el patrón "ad unit vacía = sin banner"
  (`AppView:18`, `StationDetailFeature:50`). El gate premium se apoya en él.
- TCA + SwiftUI, iOS 17+, Swift 6 strict concurrency. Ejecución directa (sin cadena de
  agentes); red de seguridad = build + tests + SwiftLint + simulador.

## Fuera de alcance (Out of scope)

- Suscripciones, tiers múltiples, paywall A/B testing, Android → si algún día entran,
  se reevalúa RevenueCat (§Riesgos).
- Histórico de precios, calculadora de viaje, alertas de bajada de precio (APNs +
  backend): features premium candidatas para v2, cada una es una fase propia.
- Cap de favoritos (descartado, ver Decisión 2).
- FM-14 (App Store prep) sigue siendo trabajo independiente, salvo la atribución IODL 2.0
  que se adelanta aquí por sinergia (§P4).

---

## Arquitectura

```
PurchaseClient (@Dependency, StoreKit 2)
    ↓ entitlement
AppFeature.onAppear → resuelve entitlement ANTES de consent/ads
    ├── premium → sin banner, sin UMP, sin ATT
    └── free    → adUnitID + requestConsent() + start()
    ↓
PaywallFeature / PaywallView (hoja) ← entry point: hoja Info/Impostazioni
```

**Decisión de diseño no obvia:** el entitlement se resuelve **antes** del flujo de
consentimiento, no después. Si no, el usuario premium ve el formulario GDPR y el prompt
de ATT que no le corresponden — y esos prompts se piden una sola vez.

**Cache síncrona del entitlement.** `PurchaseClient.isPremium() -> Bool` lee un
`LockIsolated<Bool>` sembrado al arranque desde `Transaction.currentEntitlements` y
mantenido por un listener de `Transaction.updates`. Es el **mismo patrón que ya usa
`LocationClient`** para `authorizationStatus` (coordinador + `LockIsolated`), así que
`StationDetailFeature` puede decidir sin plumbing de estado a través de dos niveles.

**Product ID:** `com.danmarjim.fuelmap.premium.noads` (non-consumable).

---

## Tareas

### P1 — `PurchaseClient` (StoreKit 2) ✅ hecho (17/07)
> P5 se adelantó: sin el `.storekit` el camino live no era verificable.
>
> **Hallazgo (bloqueante, resuelto): los builds headless firman ad-hoc y sin entitlements**
> → StoreKit devuelve `StoreKitError.notEntitled`, sin productos ni compras, y `SKTestSession`
> queda con `storefront` vacío. No era el `.storekit` ni el scheme: se descartaron apuntando
> la sesión a un archivo generado por Xcode (falla igual) y añadiendo la referencia al
> `TestAction` (no cambia nada). Se arregla con `FuelMap/FuelMap.entitlements`
> (`application-identifier` + `team-identifier`), aplicado **solo a simulador** vía
> `CODE_SIGN_ENTITLEMENTS[sdk=iphonesimulator*]`: en device/TestFlight los inyecta el
> provisioning profile y hardcodearlos ahí sería un problema.
>
> **Límite de `SKTestSession`**: `refundTransaction` no propaga la revocación a
> `currentEntitlements` (la transacción sigue con `revocationDate == nil`), y las sesiones
> se contaminan entre sí (el `storefront` de una se filtra a la siguiente). El test de
> reembolso se retira: probaría el simulador, no nuestro código. La conducta real
> (perder entitlement → vuelven ads + re-consent) se dirige desde `AppFeature` en §P2.
>
> **Otro**: `storeKitConfiguration` bajo `test:` lo ignora XcodeGen en silencio (solo
> aplica a `run:`). Innecesario: los tests usan el `PurchaseClient` mock.
- `Core/Purchases/PurchaseClient.swift` — `@Dependency`:
  - `premiumProduct: () async throws -> PremiumProduct` (id + `displayPrice` ya localizado)
  - `purchase: () async throws -> PurchaseOutcome` (`.success` / `.userCancelled` / `.pending`)
  - `restore: () async throws -> Bool`
  - `isPremium: () -> Bool` (lectura síncrona cacheada)
  - `refreshEntitlement: () async -> Bool`
  - `entitlementUpdates: () -> AsyncStream<Bool>`
- `PurchaseError` **tipado** (nunca `Error` crudo): `productUnavailable`, `failedVerification`,
  `network`, `unknown`. `userCancelled` es un *outcome*, no un error.
- `liveValue` StoreKit 2 · `previewValue` = free con producto mock · `testValue` unimplemented.
- `Core/Purchases/PurchaseStore.swift` — actor/coordinador con el `LockIsolated<Bool>` y el
  listener de `Transaction.updates` (arranca en el `.task` raíz, no en `init`).

### P2 — Entitlement en el arranque (`AppFeature`) ✅ hecho (17/07)
> `entitlementResolved` **no** se añadió al State: `bannerAdUnitID` vacío ya significa
> "sin resolver o premium", y el `if !store.bannerAdUnitID.isEmpty` que ya tenía `AppView`
> cubre el anti-parpadeo sin estado extra. `AppView` quedó sin tocar.
>
> Guard de idempotencia en `entitlementChanged`: `refresh()` puede emitir al stream el
> mismo valor ya aplicado (el arranque premium manda `entitlementLoaded` **y**
> `entitlementChanged`), y sin el guard se re-dispararía consent/start. Con test.
>
> **Verificado**: 68 tests / 19 suites verdes, SwiftLint 0, y app en simulador como
> gratuito (banner AdMob de test presente, sin regresión). El camino premium end-to-end
> queda pendiente de §P4: sin paywall no hay forma de comprar desde la UI.
- `State`: `isPremium: Bool`, `entitlementResolved: Bool`, `bannerAdUnitID`.
- `.onAppear` → `.run`: `refreshEntitlement()` → `.entitlementLoaded(isPremium)`.
  - premium → nada más: sin `adUnitID`, sin `requestConsent()`, sin `start()`.
  - free → `bannerAdUnitID = adClient.bannerAdUnitID()`, luego `requestConsent()` → `start()`.
- `.task` con `entitlementUpdates()`: compra, restore desde otro dispositivo, **refund** y
  family sharing entran por aquí y actualizan `isPremium` en vivo.
- **Sin flash de banner**: no renderizar el strip hasta `entitlementResolved`.
  `currentEntitlements` es lectura local (ms), no red. Si el simulador muestra flash,
  espejo en `UserDefaults` como *hint* de arranque (StoreKit sigue siendo la verdad).
- **Edge case del refund**: premium → refund → vuelven los ads y a ese usuario nunca se le
  pidió UMP/ATT. El listener debe disparar `requestConsent()` + `start()` al pasar a free.

### P3 — Ads off en el detalle ✅ hecho (17/07)
- `StationDetailFeature:50` → `if !purchaseClient.isPremium() { state.adUnitID = adClient.detailAdUnitID() }`.
  Usa la cache síncrona; sin cambios de estructura.

### P4 — Paywall + entry point ✅ hecho (17/07)
> **`SettingsFeature` no existe**: la hoja no tiene lógica propia, así que es una vista
> plana con callbacks (patrón de `StationListView`/`FavoritesView`). Solo el paywall es
> reducer, porque sí tiene asincronía.
>
> **Dónde vive el estado**: `isShowingSettings` + `@Presents paywall` están en `AppFeature`,
> no en `MapFeature`. La hoja necesita `isPremium`, que es estado de app; duplicarlo en el
> mapa habría quedado obsoleto justo tras comprar. El botón sube por `MapFeature.Delegate`
> (`settingsTapped`). `Delegate` va fuera de `Action` por el límite de anidamiento (1 nivel).
>
> **Legal**: solo EULA estándar de Apple. Sin privacy policy → **bloquea la submission**,
> no el desarrollo. `LegalURLs` centraliza el enlace; añadir la privacy es una línea.
>
> **Verificado en simulador**: el paywall renderiza y la clave interpolada del CTA resuelve
> en español ("Elimina los anuncios — 3,99 €"), con el precio viniendo de StoreKit. Nota:
> `simctl launch` **no aplica** el `storeKitConfiguration` del scheme (solo lo hace Xcode al
> lanzar), así que la captura se hizo con un arranque temporal + `PurchaseClient.mock()`,
> ya revertido.
>
> **NO verificado**: el tap-through real (pulsar CTA → hoja de compra de Apple → banner
> desaparece). Conducir el simulador por coordenadas resultó poco fiable (el árbol de
> accesibilidad no expone la app) y se abandonó. Pendiente: lanzar desde Xcode y comprar.

> **Deuda de diseño**: el paywall deja un hueco vertical grande entre los beneficios y el
> footer en pantallas altas. Funciona y es legible; pulir si molesta.
- `Features/Settings/SettingsFeature.swift` + `SettingsView.swift` — hoja nueva desde un
  float control (gear) en `MapView`, junto a lista/favoritos/capas. Contiene: CTA premium,
  **Ripristina acquisti**, links legales, **atribución IODL 2.0** (adelanta FM-14) y versión.
  - *Por qué una hoja y no un botón junto al banner*: la política de AdMob penaliza UI
    adyacente al banner que induzca clics accidentales.
- `Features/Premium/PaywallFeature.swift` + `PaywallView.swift`:
  - Propuesta de valor (sin anuncios · apoya la app), **precio desde `product.displayPrice`**
    — nunca hardcodeado (storefront/moneda/localización).
  - Estados explícitos: loading · error+retry · purchasing · pending (SCA) · success.
  - **Botón de restore obligatorio** (su ausencia es rechazo casi seguro en review).
  - Links a Privacy Policy y EULA (Apple los exige en el paywall).
  - `#Preview` para cada estado. Dynamic Type + VoiceOver.
- Post-compra: el banner desaparece sin relanzar (vía `entitlementUpdates`) + confirmación.

### P5 — Tooling ✅ hecho (17/07, adelantado a P1)
- `FuelMap.storekit` (config local) con el no-consumible → permite comprar, cancelar,
  refundar y probar *todo* en simulador **sin App Store Connect ni PLA**.
- `project.yml` → `schemes.FuelMap.run.storeKitConfiguration: FuelMap.storekit`.
  Obligatorio ahí: el `.xcodeproj` es generado, un ajuste a mano en el scheme se pierde
  en el siguiente `xcodegen generate`. (Verificado: XcodeGen 2.45.4 lo soporta.)

### P6 — Localización
- Strings nuevas (paywall + settings) en `Resources/Localizable.xcstrings`: it (fuente) · es · en.

### P7 — Tests (Swift Testing + `TestStore`)
- **premium → cero ads**: `adClient.requestConsent`/`start` quedan `unimplemented` → el test
  falla si se llaman. (Mismo patrón que `FavoritePricesTests` con `stationsByIDs`.)
- free → `adUnitID` + consent + start, en ese orden.
- compra OK → `isPremium` true → `bannerAdUnitID` vacío.
- cancelación → estado limpio, sin error visible.
- restore sin compras previas → mensaje, no error.
- **refund vía `entitlementUpdates`** → vuelven los ads *y* se pide consent.
- detalle premium → `adUnitID` vacío.
- Objetivo: mantener SwiftLint 0 y vigilar `type_body_length` (250) al crecer los suites —
  suite nueva `PremiumTests`, no engordar `AppFeatureTests`.

### P8 — Acciones del usuario (App Store Connect)
> No bloquean P1–P7: con `FuelMap.storekit` se desarrolla y testea entero en local.

1. **Aceptar el Paid Applications Agreement** en developer.apple.com — sin él no existen
   productos IAP ni sandbox. Ya estaba anotado como pendiente en `PHASE_LOG`.
2. Crear el no-consumible en ASC (`com.danmarjim.fuelmap.premium.noads`), precio
   (**propuesta: €3,99**), nombre/descripción en it/es/en, screenshot de review.
3. Probar en device con cuenta sandbox antes de TestFlight.

---

## Archivos a tocar

| Archivo | Acción |
|---|---|
| `Core/Purchases/PurchaseClient.swift` | nuevo — `@Dependency` StoreKit 2 |
| `Core/Purchases/PurchaseStore.swift` | nuevo — cache `LockIsolated` + `Transaction.updates` |
| `Features/Premium/PaywallFeature.swift` · `PaywallView.swift` | nuevos |
| `Features/Settings/SettingsFeature.swift` · `SettingsView.swift` | nuevos — entry point + IODL 2.0 |
| `App/AppFeature.swift` · `AppView.swift` | entitlement antes de consent; banner condicionado |
| `Features/StationDetail/StationDetailFeature.swift` | gate en `adUnitID` |
| `Features/Map/MapView.swift` | float control (gear) → hoja settings |
| `Resources/Localizable.xcstrings` | strings it/es/en |
| `FuelMap.storekit` · `project.yml` | config StoreKit + scheme |
| `FuelMapTests/PremiumTests.swift` | nuevo |

## Riesgos

- **PLA sin aceptar** → sin sandbox ni producción. Mitigado en desarrollo por el `.storekit`
  local, pero es bloqueante para TestFlight y lanzamiento.
- **Rechazo en review** por falta de restore, precio hardcodeado o ausencia de EULA/privacy
  en el paywall. Cubierto en P4.
- **Refund/family sharing** dejan el entitlement obsoleto si no se escucha
  `Transaction.updates`. Cubierto en P2 (incluido el re-consent).
- **Pago único = techo de LTV.** Aceptado a conciencia: para una utility de uso puntual la
  economía favorece al pago único (ver Decisión 3). Si el roadmap gira a suscripción o
  Android, reevaluar RevenueCat *antes* de tener base instalada de compradores.
- **Verificación en simulador** de que el banner no parpadea al arrancar como premium.

## Definición de hecho

Build verde · tests verdes (61 + nuevos) · SwiftLint 0 · verificado en simulador con
`FuelMap.storekit`: comprar → banner desaparece en mapa y detalle, sin UMP ni ATT en
arranque premium; refund → vuelven los ads y se pide consent; restore funciona.
Después: `PHASE_LOG` + `SYSTEM_MAP` + ADR-006 (StoreKit 2 sobre RevenueCat).
