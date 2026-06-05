# Phase Log — FuelMap

> Phase transitions and major milestones. Updated by agents on phase completion (via `/close-phase` skill or manually following this template).
> Append new entries at the end. The `## Current State` block at the bottom is always the snapshot of "today".

---

## Plan Iteration: Workflow — Completed
**Date:** 2026-06-04

### Architect (workflow adoption)
- Adopted Claude Code workflow system (templates, agents, hooks).
- `.claude/` scaffolded from `~/.claude/templates/`.
- Verification hook configured: `~/.claude/templates/settings-hooks-swift.json` (Swift `-parse` syntax check on Stop).
- Stack: iOS (Swift 6, SwiftUI, TCA). Type: greenfield.
- Key product/architecture decisions locked at kickoff: TCA, Supabase + GitHub Actions sync (no own backend), AdMob, iOS 17+, Italia-first.

### Developer (implementation)
- N/A — pure infrastructure setup, no code changes.

### QA (tests)
- N/A — no test changes.
- Baseline test count: 0 (greenfield).

### Review
- /init-workflow skill executed without errors.
- All artifacts verified on disk.
- Verdict: **APPROVED**.

---

## Plan Iteration: Producto & Diseño (PRD → RFC → ADRs → Issues) — Completed
**Date:** 2026-06-04

### Architect (ADR-001, ADR-002, ADR-003)
- PRD-001 redactado y **Approved** con open questions críticas validadas vía research web (endpoints MIMIT reales, límites Supabase free tier, requisitos AdMob ATT/UMP).
- Hallazgo clave: CSV MIMIT con separador **`|` (pipe)** desde 2026-02-10; `anagrafica` con línea `Estrazione del ...` a saltar; `descCarburante` en texto libre con muchas variantes.
- RFC-001 **Accepted**: arquitectura iOS (TCA) + Supabase (PostGIS, RPC `nearby_stations`, RLS read-only) + sync diario GitHub Actions; esquema SQL, contratos `@Dependency`, plan §4 de 14 issues, riesgos y testing.
- ADR-001 (capa de datos Supabase, sin BE propio), ADR-002 (TCA), ADR-003 (normalización combustible con `fuel_raw`).

### Developer (implementation)
- N/A — fase de producto/diseño, sin código.

### QA (tests)
- N/A — estrategia de test definida en RFC §7 (TestStore por reducer, parse de CSV con fixtures, RPC con seed).

### Review
- Decisiones validadas contra fuentes oficiales (MIMIT en vivo, Supabase pricing, AdMob docs).
- Artefactos verificados en disco: PRD, RFC, 3 ADRs, 14 issues.
- Verdict: **APPROVED**.

---

## Plan Iteration: FM-1 — Proyecto Xcode + TCA — Completed
**Date:** 2026-06-04

### Architect (ADR-002)
- Tooling: **XcodeGen** (`project.yml`) elegido sobre Tuist / .xcodeproj commiteado.
- Decisión de ejecución: en FM-1 solo se añade el paquete SPM **TCA**; `supabase-swift` y `GoogleMobileAds` se incorporan en FM-5/FM-11 para mantener el build inicial ligero y correr la app contra mocks (petición del usuario).

### Developer (implementation)
- `project.yml` (XcodeGen): target iOS 17, Swift 6 `complete` strict concurrency, paquete TCA `from 1.15.0`.
- `FuelMap/App/`: `FuelMapApp.swift` (@main + Store raíz), `AppFeature.swift` (reducer esqueleto), `AppView.swift` (placeholder `ContentUnavailableView`).
- `.gitignore` actualizado para `.xcodeproj` generado.

### QA (tests)
- `FuelMapTests/AppFeatureTests.swift` — Swift Testing, smoke con `TestStore` (`onAppear` sin efectos pendientes).
- **BUILD SUCCEEDED** (iPhone 17, iOS 26.5 sim). **TEST: 1 test passing**. SwiftLint: 0 violations. Sin warnings de concurrencia.

### Review
- Problemas resueltos en verificación: (1) macros TCA → `-skipMacroValidation`; (2) *undefined symbols* `CasePathsCore`/`PerceptionCore` al testear → el test target depende SOLO del host app (no re-enlaza el paquete TCA).
- Entorno: Xcode 26.5 vía `DEVELOPER_DIR` (xcode-select apunta a CLT; sin `sudo`).
- Verdict: **APPROVED**.

---

## Plan Iteration: FM-4 — Modelos + DTOs + Mapeo — Completed
**Date:** 2026-06-04

### Architect (RFC §2.2, §3.1, §3.2; ADR-003)
- Separación wire/dominio: DTO `Decodable` (snake_case) ↔ `StationMapper` ↔ modelos `Sendable`.
- Validación de coords agnóstica al país (rango mundial) para escalabilidad; `(0,0)`/nulas descartadas (NF6).
- Precios redondeados a 3 decimales en el límite del mapeo para neutralizar imprecisión de `Decimal` desde JSON.

### Developer (implementation)
- `Core/Models/`: `Station` (con `cheapest`), `FuelPrice`, `FuelType` (rawValue = normalización backend), `Coordinate` (`validated`).
- `Core/Network/DTOs/`: `NearbyStationRowDTO`, `StationMapper`, `JSONDecoder+FuelMap` (convertFromSnakeCase + ISO8601), `ISO8601` (tolerante a fracciones).
- `Core/Foundation/`: `Decimal+Rounding`, `String+NilIfEmpty`.
- DTOs `Decodable` (nunca `Codable`). Sin dependencia de backend ni red.

### QA (tests)
- `StationMapperTests` (6): agrupación por id, descarte de coords inválidas, normalización fuel→`.altro`, redondeo, `cheapest`.
- `FuelTypeTests` (2): rawValues canónicos y fallback de desconocidos.
- **8 tests passing** (incluye el smoke de FM-1). SwiftLint: 0 violations.

### Review
- Quirk transitorio: el simulador falló a veces al lanzar (`preflight checks / Busy`); se resuelve con `simctl bootstatus` antes del test (no es código).
- Verdict: **APPROVED**.

---

## Plan Iteration: FM-6 — LocationClient + permisos — Completed
**Date:** 2026-06-04

### Architect (RFC §3.3, §6.1)
- `LocationClient` como `@Dependency` (struct de closures `@Sendable`): status síncrono + async para request/location.
- Coordinador `@MainActor` (Sendable) propietario de `CLLocationManager`; delegate→continuations; `LockIsolated<CLAuthorizationStatus>` para lectura síncrona thread-safe.
- `currentLocation` lanza `LocationError.authorizationDenied` sin permiso; live `desiredAccuracy` = 100 m.

### Developer (implementation)
- `Core/Location/LocationClient.swift` (+ `LocationError`, registro en `DependencyValues`, `testValue` unimplemented).
- `project.yml`: `NSLocationWhenInUseUsageDescription` (base it; l10n en FM-13).

### QA (tests)
- `LocationClientTests` (3): notDetermined→request, denied→throws, authorized→coordinate (stubs inyectables).
- **11 tests passing**. SwiftLint 0.

### Review
- Swift 6 strict: resueltos (1) `LockIsolated.setValue` autoclosure `@Sendable` → extraer local; (2) captura de `manager` no-Sendable en `assumeIsolated` → extraer valores Sendable (status/coordenada) en contexto `nonisolated` antes de cruzar al main actor.
- La lógica live de CoreLocation requiere integración/manual (no unit-testable); el contrato sí está cubierto.
- Verdict: **APPROVED**.

---

## Plan Iteration: FM-5 — APIClient (mock) — Completed
**Date:** 2026-06-04

### Architect (RFC §3.2; ADR-001)
- `APIClient` `@Dependency` (`nearbyStations`, `stationDetail`) con `APIError` tipado.
- **Ajuste de scope (estrategia mock):** `liveValue` es temporalmente un mock con fixtures; la implementación real sobre `supabase-swift` llega con FM-2/FM-3 (cambio de una línea en `liveValue`, contrato intacto).

### Developer (implementation)
- `Core/Network/APIClient.swift`: contrato + `APIError` + `DependencyKey` (live/preview = mock; testValue unimplemented) + registro en `DependencyValues`.
- `Core/Network/APIClient+Mock.swift`: `mock()` (filtra por fuel/self, ordena por precio asc) + `StationFixtures` (6 estaciones de Roma con benzina/gasolio, self/servito).

### QA (tests)
- `APIClientTests` (5): orden por precio asc, selfOnly excluye servito, filtro por combustible, detalle completo, id desconocido → `noResults`.
- **16 tests passing**. SwiftLint 0.

### Review
- Bug propio detectado por test: la más barata en benzina self es id 4 (1.849), no id 2 — corregido en el test.
- Riesgo anotado: no enviar el mock a producción → swap obligatorio en FM-5-real (FM-2/FM-3) y verificación en FM-14.
- Verdict: **APPROVED**.

---

## Plan Iteration: FM-7 — MapFeature + MapView — Completed
**Date:** 2026-06-04

### Architect (RFC §6.2, §1; ADR-002)
- `MapFeature` reducer: onAppear→permiso→ubicación (o centro Italia por defecto); carga por centro con `.cancellable(cancelInFlight:)` + debounce 400 ms (`continuousClock`); guard de jitter; `stationTapped`→`selected`; error tipado→mensaje.
- `AppFeature` compone `MapFeature` vía `Scope`.

### Developer (implementation)
- `Features/Map/`: `MapFeature` (reducer), `MapView` (`Map` iOS 17, annotations de precio, `onMapCameraChange(.onEnd)`, recentrado one-shot, status bar loading/empty/error), `StationPin` (cápsula de precio).
- `App/AppFeature` + `App/AppView` reescritos para alojar el mapa.
- Mock (`APIClient+Mock`) trasladado para situar fixtures alrededor del centro pedido (demo con cualquier ubicación).

### QA (tests)
- `MapFeatureTests` (6): onAppear con/sin permiso, debounce+cancelación, guard de jitter, fallo→error, tap→selected. `AppFeatureTests` actualizado (composición). 
- **22 tests passing**. SwiftLint 0.

### Review
- **Bug encontrado en simulador y corregido:** `onMapCameraChange` se re-disparaba con micro-jitter, cancelando la carga debounced en vuelo y dejando `isLoading` pegado ("Caricamento…" perpetuo). Fix: guard de epsilon (0.0005°) en `mapCameraChanged` → también reduce consultas (NF1).
- Verificado en simulador (iPhone 17, iOS 26.5): pins de precio sobre Roma, banner se limpia, recentrado y debounce OK (capturas).
- **Deuda registrada:** clustering real (PRD F6) — SwiftUI `Map` iOS 17 no clusteriza annotations custom; con ~22k estaciones reales hará falta `MKMapView`+`MKClusterAnnotation` o clustering por grid. No necesario con el mock (6). Ver plan.md.
- Verdict: **APPROVED (con deuda de clustering)**.

---

## Plan Iteration: FM-8 — FiltersFeature + FiltersView — Completed
**Date:** 2026-06-04

### Architect (RFC §6.2)
- `fuel`/`selfOnly`/`radiusKm` movidos de `MapFeature.State` a `FiltersFeature.State` (`BindingReducer`).
- `MapFeature` compone `FiltersFeature` (`Scope`) y recarga ante cualquier acción `.filters`.

### Developer (implementation)
- `Features/Filters/`: `FiltersFeature` (`BindableAction`), `FiltersView` (segmented combustible + toggle self + menú radio, panel inferior con material). `RadiusOption` {1,3,5,10,20}.
- `MapFeature`/`MapView`/`AppFeature` adaptados; `load()` lee `state.filters`.
- `FuelType.selectable` + `label`. Fixtures enriquecidas (GPL en 1/3/4, metano en 5/6) para que cambiar de combustible sea visible.

### QA (tests)
- `FiltersFeatureTests` (3): toggle self, cambio de combustible, cambio de radio. `MapFeatureTests`: cambio de filtro recarga. `AppFeatureTests` actualizado (`filters.fuel`).
- **26 tests passing**. SwiftLint 0.

### Review
- Verificado en simulador: panel de filtros (Benzina/Gasolio/GPL/Metano + Self + radio) sobre el mapa con pins. Tap headless no probado (sin idb) pero comportamiento cubierto por tests.
- Verdict: **APPROVED**.

---

## Plan Iteration: FM-9 — StationDetail — Completed
**Date:** 2026-06-04

### Architect (RFC §6.2)
- Presentación con `@Presents`/`.ifLet`/`.sheet`; el pin pre-rellena la estación y `onAppear` refina con `stationDetail` (todos los combustibles).
- Deep link a Apple Maps vía `@Dependency(\.openURL)`; cierre vía `@Dependency(\.dismiss)`.

### Developer (implementation)
- `Features/StationDetail/`: `StationDetailFeature` (carga, directions, close), `StationDetailView` (sheet con precios por combustible self/servito, hora de actualización, "Indicazioni", estados loading/error).
- `MapFeature`: `selected` → `@Presents detail`; `stationTapped` presenta; `.ifLet`. `MapView`: `.sheet(item:)` con detents medium/large.

### QA (tests)
- `StationDetailFeatureTests` (3): carga detalle completo, fallo sin datos→error, directions abre Apple Maps con destino correcto. `MapFeatureTests`: tap presenta detalle.
- **29 tests passing**. SwiftLint 0.

### Review
- App verificada sin crash en simulador (wiring de presentación). Captura del sheet no posible headless (sin idb/tap), cubierto por tests + preview.
- Verdict: **APPROVED**.

---

## Plan Iteration: FM-10 — Más barata destacada + orden — Completed
**Date:** 2026-06-04

### Architect (RFC §4; PRD F7, F13)
- `cheapestStationID` derivado al recibir estaciones (F7); `StationSort {price, distance}` + `sortedStations` computado (F13).
- `Coordinate.distance(to:)` (haversine) en el modelo de dominio (testeable, sin CoreLocation).

### Developer (implementation)
- `MapFeature`: `sortOrder`, `cheapestStationID`, `sortedStations`; acciones `sortOrderChanged`/`recenterOnStation`. `StationPin` verde si más barata.
- `Features/Map/StationListView`: lista ordenable (segmented precio/distancia), distancia por fila, fila→recentrar; sheet desde botón en el mapa.
- `Coordinate.distance(to:)`.

### QA (tests)
- `MapFeatureTests`: marca la más barata, `sortedStations` por precio y distancia. `CoordinateTests` (2): `validated`, `distance` (Roma↔Milán ≈477 km). 
- **33 tests passing**. SwiftLint 0.

### Review
- Verificado en simulador: pin más barato en **verde** (id 4, 1.849 €) y botón de lista. La lista (sort) requiere tap headless → cubierta por tests.
- Verdict: **APPROVED**.

---

## Plan Iteration: FM-13 — Accesibilidad, estados y localización — Completed
**Date:** 2026-06-05

### Architect (RFC §7; PRD NF5, NF6)
- Localización vía **String Catalog** (`Localizable.xcstrings`), fuente it + es + en; claves = textos italianos fuente.
- VoiceOver: pins anuncian nombre + combustible + precio (+ "más económico").

### Developer (implementation)
- `Resources/Localizable.xcstrings` con todos los textos UI (it/es/en).
- `FuelType.label` y `APIError.userMessage` (Map y Detail) → `String(localized:)`.
- `StationPin`: param `fuel`, accesibilidad mejorada; `MapView` pasa el combustible; `statusBar` refactorizado (helper `banner`, sin duplicación).
- `StationDetailView.priceLabel` → `LocalizedStringKey` (Self/Servito localizados); título fallback localizado.

### QA (tests)
- `FuelTypeTests`: `label` no vacía para todos los casos. 
- **34 tests passing**. SwiftLint 0.

### Review
- Verificado en simulador forzando idioma: **es** (Gasolina/Diésel/GLP/Metano, Autoservicio) y **en** (Petrol/Diesel/LPG/CNG, Self-service). it por defecto.
- Dynamic Type cubierto por fonts semánticas (sin tamaños fijos); auditoría AX Inspector es paso manual no headless.
- Pendiente menor: la usage description de ubicación (`Info.plist`) sigue en italiano → localizar en FM-14 (InfoPlist.xcstrings).
- Verdict: **APPROVED**.

---

## Plan Iteration: FM-12 — Favoritos (SwiftData) — Completed
**Date:** 2026-06-05

### Architect (RFC §4; PRD F11)
- Persistencia SwiftData aislada con **`@ModelActor`** (`FavoritesStore`) tras un `FavoritesClient` (`@Dependency` de closures `@Sendable`) — sin acoplar SwiftData a las vistas ni romper Swift 6 strict.
- Tipos Sendable (`FavoriteStationInfo`, `FavoriteInput`) cruzan el límite del actor; los `@Model` no.

### Developer (implementation)
- `Core/Persistence/`: `FavoriteStation` (`@Model`), `FavoritesClient` (+`FavoritesStore`, `ModelContainer.fuelMapShared`, in-memory para test/preview).
- `StationDetailFeature`/View: estado `isFavorite`, carga en onAppear (merge), `favoriteToggled`, botón estrella en la barra.
- `MapFeature`/View: `favorites`, `loadFavorites` (onAppear + al cerrar el detalle), `favoriteSelected`→recentrar; botón ★ + `FavoritesView` (sheet).
- Localización de las 4 cadenas nuevas (it/es/en). No se usa `.modelContainer` en vista (acceso vía client).

### QA (tests)
- `FavoritesClientTests` (2): toggle add/remove + isFavorite/all; orden por recencia. `StationDetailFeatureTests`: toggle marca/desmarca. `MapFeatureTests`: loadFavorites puebla.
- **38 tests passing**. SwiftLint 0.

### Review
- Verificado en simulador: botón ★ junto al de lista; app sin crash. La hoja de favoritos requiere tap headless → cubierta por tests.
- `force_try` documentado solo en fallbacks de creación de contenedor en memoria.
- Verdict: **APPROVED**.

---

## Plan Iteration: FM-11 — AdMob + UMP + ATT — Completed
**Date:** 2026-06-05

### Architect (RFC §6.4, §3.3)
- `AdClient` (`@Dependency`): `start` (SDK), `requestConsent` (UMP→ATT), `bannerAdUnitID`. Banner FUERA del mapa (PRD F8).
- Info.plist explícito (XcodeGen `info`) para `GADApplicationIdentifier` + `NSUserTrackingUsageDescription` (no expresables con GENERATE_INFOPLIST_FILE).

### Developer (implementation)
- SPM: GoogleMobileAds 11.13.0 + GoogleUserMessagingPlatform 2.7.0 (API v11 `GAD*`/`UMP*`, `@preconcurrency import`).
- `Core/Ads/`: `AdClient` (+`AdConsentCoordinator`, `AdSDK`, `topViewController`), `BannerAdView` (`GADBannerView`, `load(_:)`).
- `AppFeature.onAppear`→`requestConsent()`+`start()`; `AppView` aloja el banner bajo el mapa.
- `project.yml`: Info.plist generado (gitignored) con keys de ads/ATT; IDs de TEST de Google.

### QA (tests)
- `AppFeatureTests`: onAppear ejecuta consent y luego start (orden verificado con spy).
- **39 tests passing**. SwiftLint 0.

### Review
- Verificado en simulador (install limpio): **formulario UMP** (test), prompt de ubicación y **banner AdMob en modo test** ("Test mode/Nice job!") visibles. ATT tras UMP (no tap headless).
- Deuda → FM-14: ad unit real, `SKAdNetworkItems`, l10n del Info.plist.
- Verdict: **APPROVED**.

---

## Plan Iteration: Evaluación multi-agente + remediación — Completed
**Date:** 2026-06-05

### Architect (review)
- Análisis Opus de docs (PRD/RFC/ADRs vs código) + 3 agentes (Opus corrección/concurrencia, Sonnet HIG/a11y, Sonnet calidad/consistencia). Informe en `.claude/reviews/2026-06-05-evaluacion-completa.md`.
- Hallazgo crítico no previsto: `Store` raíz recreado en `body` (C1). Premisa falsa del RFC §5 (clustering nativo) → C2.

### Developer (remediación, 3 tandas)
- Tanda 1: C1 (Store @State), H4a (maps://), H4b (banner adaptativo), M7 (formatters cacheados), dedup /simplify (precio, userMessage, conversores coordenada, italyDefault), StationSort localizado.
- Tanda 2: H1 (recenter consumible), M1 (adClient→State), M2 (favoritos no-op fallback sin try!), M6 (distanceM fuera del DTO).
- Tanda 3: H2 (Dynamic Type pin/filtros/detalle), H3 (touch targets 44pt), M3 (VoiceOver), M4 (más barata con forma+color), estado vacío de precios, banner multilínea; 3 strings nuevas it/es/en.

### QA (tests)
- Nuevos: `map_recenter_isConsumable`; `AppFeatureTests` actualizado (bannerAdUnitID).
- **40 tests passing**. SwiftLint 0. Dynamic Type confirmado aplicándose en simulador.

### Review
- Diferido a **FM-15** (clustering, bloqueante pre-datos reales). Desviaciones documentales → addendum RFC §11.
- Pendientes menores anotados en plan (carga inicial supeditada a permiso; pulido a11y).
- Verdict: **APPROVED**.

---

## Current State
**Date:** 2026-06-05
- **App completa (mock), monetizada y revisada:** mapa + filtros + lista + detalle + favoritos; localizada it/es/en; banner AdMob (test) + UMP/ATT. Remediación de la evaluación multi-agente aplicada.
- `Core/{Models,Network,Location,Persistence,Ads,Foundation}` + `Features/{Map,Filters,StationDetail}`. 40 tests, SwiftLint 0.
- `APIClient.liveValue` = mock (TEMP hasta Supabase FM-2/FM-3).
- XcodeGen; deps SPM: TCA + GoogleMobileAds + UMP. Info.plist explícito (gitignored).
- Issues hechos: FM-1, FM-4, FM-5 (mock), FM-6…FM-13. Pendientes: FM-2/FM-3 (backend), FM-5 real, **FM-15 (clustering, 🔴 pre-datos reales)**, FM-14 (App Store prep).
- **Próximo paso:** backend real (FM-2/FM-3/FM-5) o FM-15 (clustering) o FM-14.

---

> ## Usage rules
>
> - **Append, never rewrite** older entries. They are historical record.
> - **`Current State`** is the only block that gets replaced — always overwrite with the latest snapshot at the end of every phase.
> - **Date format**: `YYYY-MM-DD`. No ambiguous formats.
> - **One iteration = one block**. A "Plan Iteration" is a coherent unit of work cleared by a reviewer.
> - **Architect / Developer / QA / Review subsections** must each contain real content. If a role didn't participate, state "N/A — ..." rather than omitting.
> - **Reference ADRs by number** in Architect subsection when they exist.
> - **Bullet style**: short, factual, with file/component references where useful.
