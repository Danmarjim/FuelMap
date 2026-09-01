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

## Plan Iteration: FM-2 + FM-3 — Backend (Supabase + sync MIMIT) — Code complete
**Date:** 2026-06-05

### Architect (RFC §2.1, §3.1, §6.3; ADR-001, ADR-003)
- Esquema SQL (`stations`/`prices`/`sync_runs`) + PostGIS + RPC `nearby_stations` + RLS read-only (anon) + grants explícitos.
- Sync en Node 22, lógica pura (parse + fuel-mapping) separada para testeo sin red.

### Developer (implementation)
- `backend/migrations/0001_init.sql` (FM-2).
- `backend/sync/`: `parse.mjs`, `fuel-mapping.mjs`, `sync.mjs` (@supabase/supabase-js), `package.json`.
- `.github/workflows/sync-mimit.yml` (cron 06:30 UTC + dispatch). `backend/README.md` (runbook). `.gitignore`: `node_modules/`.

### QA (tests)
- `sync.test.mjs` (3, `node --test`): mapeo fuel, parse anagrafica (coords), parse prezzo (self/precio/no-mapeadas).
- **Verificado contra CSV reales del MIMIT**: 23.707 stations válidas / 106 descartadas / 0 malformed; 93.050 precios / 0 skipped; normalización benzina 36.6k·gasolio 45.2k·gpl 4.7k·hvo 3.9k·metano 1.9k·altro 729.

### Review
- No ejecutable end-to-end en local (Docker no disponible → sin Supabase local). El parser (parte de mayor riesgo) sí está verificado con datos reales.
- **Despliegue cloud pendiente (cuenta del usuario):** crear proyecto Supabase, aplicar migración, secrets, push. Runbook en `backend/README.md`.
- Verdict: **APPROVED (code-complete; deploy pendiente)**.

---

## Plan Iteration: FM-5 real + data-quality — Completed
**Date:** 2026-06-05

### Architect (RFC §3.1, §3.2; ADR-001)
- `APIClient.liveValue` = Supabase real (supabase-swift 2.46) contra RPC `nearby_stations`/`station_detail`; `previewValue`=mock, `testValue`=unimplemented. Contrato intacto.
- RPC `station_detail` (migración 0002) para el detalle (todos los combustibles), reutilizando DTO + mapper.
- Calidad de datos: filtro de precio plausible [0.3, 6.0] en el sync (el MIMIT trae basura tipo 0.1 €).

### Developer (implementation)
- `Core/Network/`: `SupabaseConfig` (URL + anon key), `APIClient+Live`. `APIClient` DependencyKey actualizado.
- `backend/migrations/0002_station_detail.sql`. `backend/sync/parse.mjs` filtro de precio + test.

### QA (tests)
- 40 tests iOS (mock en previews/tests) + 3 backend. RPC verificada vía anon key (200 estaciones Roma, RLS ok). Repoblado en CI tras el fix → más barata real 1.639 € (antes 0.1 € basura).

### Review
- App iOS lee datos reales (mapa + lista vía `nearby_stations`). Detalle requiere aplicar 0002 (acción del usuario en SQL editor).
- Verificación visual en simulador pendiente del usuario (el overlay de consentimiento UMP bloquea screenshots headless).
- Verdict: **APPROVED**.

---

## Plan Iteration: FM-15 — Clustering de pins — Completed
**Date:** 2026-06-05

### Architect (ADR-004; PRD F6; RFC §5/§11)
- Clustering por grid en el reducer (función pura) manteniendo `Map` SwiftUI; descartado MKMapView (dataset acotado por `limit 200`, testeabilidad TCA).

### Developer (implementation)
- `Features/Map/MapClustering.swift` (`MapItem`/`StationCluster` + algoritmo por celdas∝zoom), `ClusterPin.swift`.
- `MapFeature`: `span` desde la cámara, `mapItems` computado, `clusterTapped` (zoom in). `MapView`: render por `mapItems` (`@MapContentBuilder`).

### QA (tests)
- `MapClusteringTests` (4: span grande→1 cluster, span diminuto→individuales, conserva total, span 0) + `clusterTapped`. **45 tests iOS**. SwiftLint 0.

### Review
- Verificación visual limpia pendiente de tap manual (overlay UMP bloquea headless); datos reales + clusters visibles asomando tras el consentimiento.
- Verdict: **APPROVED**.

---

## Plan Iteration: UX Enrichment (FM-16/17/18/19) — Completed
**Date:** 2026-06-05

### Architect (ideación + benchmark)
- Benchmark de apps (Prezzi Benzina, GasBuddy, Waze/Google Maps): su debilidad (datos viejos) = nuestra ventaja (MIMIT oficial). Validan navegación integrada y "heat map".
- Lógica pura para color (terciles) y marca (normalización) → testeable.

### Developer (implementation)
- FM-18 `PriceTiers` (terciles) → color verde/naranja/rojo en `StationPin`/`ClusterPin`.
- FM-16 `BrandStyle`+`BrandBadge` (color+monograma; logo real = drop-in asset, sin scraping). Monograma en pin, badge en detalle.
- FM-17 `NavApp` (Apple/Google/Waze) + `confirmationDialog` con apps instaladas (`LSApplicationQueriesSchemes`).
- FM-19 HVO en `selectable`; frescura relativa del precio en el detalle (highlight si >2 días).
- `.swiftlint.yml` (permite `id`/`q8`/`ip`).

### QA (tests)
- `PriceTiersTests`, `BrandStyleTests`, `NavAppTests` + `navigate(.googleMaps)`. **49 tests iOS**. SwiftLint 0.

### Review
- Verificación visual limpia pendiente de tap manual (overlay de consentimiento); pines de color (heat map) confirmados con datos reales tras el overlay.
- Verdict: **APPROVED**.

---

## Plan Iteration: RESTYLE-001 — Restyle visual completo — Completed
**Date:** 2026-06-08

### Architect (design system)
- Tokens semánticos en Asset Catalog 1:1 con `tokens.css`; tiers de precio daltónico-seguros (color+forma+etiqueta); fills de tier mode-independent. ADR-005.
- Fases R0 (fundación) → R5 (estados/a11y): tokens, `PriceTier`, pins/cluster/chrome+capas, filtros, sheets, skeletons/Reduce Motion/Dynamic Type.

### Developer (implementation)
- Nuevo: `DesignSystem/{Spacing,Radius,Elevation,Typography,TokenGallery}`, `Features/Map/SheetComponents`, 35+`goldInk` Color sets, `Core/Foundation/PriceFreshness`, `FuelVariantBuilder`.
- Migrados: StationPin, ClusterPin, BrandBadge, MapView/MapFeature (control de capas `mapStyle`), FiltersView, StationListView, FavoritesView, StationDetailView, AppView. Strings it/es/en.

### QA (tests)
- +6 tests: tier forma/etiqueta, `mapStyleChanged`, `FuelVariantBuilder` (agrupación/orden/variantes), `PriceFreshness` (umbral 48h). **57 tests, SwiftLint 0.**
- Informe de cobertura: `.claude/reviews/2026-06-08-restyle-qa.md` (veredicto: suficiente).

### Review
- `.claude/reviews/2026-06-08-restyle-review.md` (ios-reviewer, /simplify primero). 1 bug bloqueante (A-1 doble unidad € en fila) + altos/medios.
- Remediación aplicada: A-1 (`fuelPriceValue` número-solo), M-2 (tiers desde el store), M-3 (nav apps cacheadas), dedup `SortPill`, extracción de lógica pura (variants/freshness) + tests.
- Diferido (deuda menor): ring hairline de elevación en oscuro (M-4), dedup de `separator`, nits varios.
- Verdict: **APPROVED** tras remediación.

---

## Plan Iteration: Sync MIMIT — fix cron `fetch failed` — Completed
**Date:** 2026-06-09

### Architect (diagnóstico)
- N/A — fix de mantenimiento (Quick Execution), sin decisiones de arquitectura.
- Causa raíz del run fallido (06-08, `27134391155`): step `node sync.mjs` con `SYNC FAILED: fetch failed` — timeout/reset transitorio del servidor público del MIMIT al descargar los CSV. Tests del parser OK (3/3). El warning de Node 20 era ruido (deprecación de actions, no la causa). Endpoints confirmados HTTP 200 al diagnosticar.

### Developer (implementation)
- `backend/sync/sync.mjs`: `download()` con **retry 3× backoff exponencial (2s, 4s)** + timeout explícito **60s** (`AbortSignal.timeout`). Antes un único `fetch` fallido tumbaba el sync diario.
- `.github/workflows/sync-mimit.yml`: `checkout`/`setup-node` **v4 → v5** (Node 24; elimina warning de deprecación).
- Commit `55ba708` en `main` (acotado a esos 2 archivos; cambios iOS en curso sin tocar).

### QA (tests)
- `node --check` OK; tests del parser **3/3** (sin cambios — el retry no es unit-testeable sin mock de red).

### Review
- Validación end-to-end: run manual `27196007918` en **verde** (51s), actions v5 sin warning de Node 20, `OK — extracción 2026-06-08: 23718 stations, 92223 prices, 106 descartadas`.
- Cron diario siguiente (06:30 UTC) ya usará la versión robusta en `main`.
- Verdict: **APPROVED**.

---

## Plan Iteration: App Icon (APPICON-001) — Completed
**Date:** 2026-07-17

### Architect (dirección de diseño)
- Skill `opendesign:svg-design` instalada en scope user (`claude plugin install opendesign@opendata-skills`, v1.3.2). El repo `tryopendata/skills` **no tiene skill de "appIcon"**: solo `opendata`, `openchart` y `opendesign` (SVG logos/iconos). No es un generador de app icons de iOS — diseña el SVG; la rasterización y el appiconset se hacen a mano.
- Dirección acordada con el usuario vía el paso 0 obligatorio de la skill: precio/ahorro primero · métafora "encontrar barato cerca" · referencia estética Google Maps · **gasolinera como héroe + € como métafora de ahorro** (aclarado en la 4ª ronda).
- Paleta anclada a `.claude/design/assets/tokens.css`, no a hex sueltos: azure #0072E6, `cheapestGold` #F5B301, azure profundo #005BB8.
- 3 rondas de ideación, 13 conceptos, 4 categorías estructurales (símbolo, espacio negativo, geométrico abstracto, letterform). Descartes documentados en `.claude/design/appicon/README.md`.

### Developer (implementación)
- Elegido **G2 "Colonnina bold"**: `.claude/design/appicon/icon-colonnina-bold.svg` → `FuelMap/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` (1024², RGB sin alfa).
- `AppIcon.appiconset/Contents.json`: añadido `filename` al slot 1024 (estaba vacío desde 06-05).
- Decisión de contraste: display en oro con € en azure profundo, **no** € oro sobre blanco (~1.9:1, ilegible).
- Sin rasterizador SVG en la máquina (ni `rsvg-convert`, ni `cairosvg` con libcairo, ni ImageMagick) → pipeline con Chrome headless + Pillow. Documentado en el README.
- Herramienta propia: `squircle-sheet.html`, hoja de contactos con la máscara squircle de iOS a 180/120/80/60/40pt. El `preview.html` de la skill es para logos (favicon/nav bar) y no enmascara.

### QA (tests)
- N/A — cambio de assets, sin superficie de código. Test count sin cambios (**57**).
- Verificación visual a los 5 tamaños de home screen con máscara squircle en cada ronda; los descartes salieron de esa lectura (Totem = bocadillo de chat, Pompa-pin = surtidor goteando, Due prezzi = skeleton loader).

### Review
- `xcodegen generate` + `xcodebuild build` (iPhone 17 sim): **BUILD SUCCEEDED**.
- Icono verificado **dentro del bundle**, no solo en el catálogo: `actool` derivó `AppIcon60x60@2x.png` y `AppIcon76x76@2x~ipad.png`; `Info.plist` con `CFBundleIconName = AppIcon`. PNG compilado inspeccionado a 120².
- Verdict: **APPROVED**.

---

## Plan Iteration: Favoritos con precio en vivo (FAV-PRICE) — Completed
**Date:** 2026-07-17

### Architect (decisiones)
- N/A como fase de plan: FAV-PRICE salda la deuda diferida de RESTYLE-001 R4/R6 ("favoritos sin precio/tier en vivo"), no una fase nueva de `plan.md`.
- **Filtrado en servidor, no en cliente**: RPC nueva `stations_by_ids(in_ids, in_fuel, in_self_only)` en vez de N llamadas a `station_detail` o traerse todos los combustibles y filtrar en el dispositivo. Un round-trip por refresco.
- **Mismo shape que `nearby_stations`** → reutiliza `NearbyStationRowDTO` + `StationMapper` sin código de mapeo nuevo. `distance_m = 0`: la distancia se calcula en cliente desde la ubicación real del usuario.
- Sin ADR: no cambia arquitectura; es una RPC más dentro del patrón ya congelado por ADR-001/003.

### Developer (implementation)
- `backend/migrations/0004_stations_by_ids.sql`: RPC `stable`, `search_path` fijado, grants a `anon`/`authenticated`, idempotente (`create or replace`).
- `APIClient`: tercer endpoint `stationsByIDs` (live vía RPC, mock filtrando fixtures, `testValue` unimplemented).
- `MapFeature`: `favoriteStations` + `isLoadingFavoritePrices` en State; efecto `loadFavoritePrices` cancelable (`CancelID.favoritePrices`), disparado tras `favoritesResponse` y **fusionado con `load` en cualquier cambio de filtro**. Sin favoritos no hay red.
- `MapFeature+Favorites.swift` (extraído: el original superaba las 400 líneas de `file_length`): derivados `favoriteDisplays` / `cheapestFavoriteID` / `favoritePriceTiers` + `FavoriteDisplay`. Orden por precio asc, **desempate por distancia** (`order` solo cierra el empate exacto precio+distancia, para estabilidad); los sin precio, al final. `FavoriteDisplay` lleva su `distance` calculada una vez en el store → `FavoritesView` ya no recibe `origin` ni recalcula distancia por fila y en VoiceOver.
- `FavoritesView`: filas con distancia, precio, `TierTag`, `BestFlag` en el más barato y nota "n/d" si el favorito no vende el combustible activo. VoiceOver compone nombre + distancia + precio + tier. Skeleton solo en la **primera** carga; en refrescos conserva los precios previos.
- Fallo de red **silencioso**: la hoja sigue usable por nombre/distancia en vez de vaciarse.
- Colado en el mismo commit (no es de FAV-PRICE): `MapDefaults.span` **0.08 → 0.02** — zoom inicial ≈5 km, menos pines a la vista.
- Commits: `7f38897` (feature) + `d9b0f2b` (remediación de review).

### QA (tests)
- `FavoritePricesTests.swift` (nuevo, 5 tests): carga + fetch de precios · sin favoritos no toca la API (`stationsByIDs` queda `unimplemented`, falla el test si se llama) · orden por precio con el "no disponible" al final · desempate por distancia · cambio de combustible refresca (Esso sin GPL → sin precio).
- El test del desempate **construye sus estaciones**: las fixtures no tienen dos precios iguales para ningún combustible, así que el empate no era reproducible con `StationFixtures`. Incluye una más barata y lejana para fijar que el precio no cede prioridad a la distancia.
- `MapFeatureTests`: `clusterTapped` ahora asienta sobre `MapDefaults.span` en vez del literal.
- **61 tests en 17 suites, todos verdes** (57 → 61). SwiftLint **0**. `xcodebuild test` (iPhone 17 sim): **TEST SUCCEEDED**.

### Review
- **Colisión de migraciones**: la RPC entró como `0003_stations_by_ids.sql` con `0003_expose_fuel_raw.sql` ya ocupando ese número → renumerada a `0004`. El orden de aplicación manual en el SQL editor es la única garantía de secuencia; dos `0003` la rompen.
- **Regresión de lint**: los 4 tests nuevos llevaron `MapFeatureTests` a 285 líneas (`type_body_length`, límite 250) rompiendo el SwiftLint 0 del repo → extraídos a `FavoritePricesTests`.
- `stations_by_ids` **no devuelve `fuel_raw`** (sí lo hacen las RPC tocadas por `0003_expose_fuel_raw`). No rompe: `NearbyStationRowDTO.fuelRaw` es opcional y `StationMapper` cae a `row.fuel`. La hoja de favoritos muestra el precio más barato, no la variante — sin impacto visible. Añadir la columna si algún día la hoja muestra variante real.
- **Verificación end-to-end** (07-17): `0004` aplicada en Supabase por el usuario; RPC probada con la `anonKey` (mismo camino que la app) → precios reales, `in_self_only` filtrando en servidor (4 filas → 2), un ID del lote ausente por no vender el combustible (el caso "n/d" real) y `distance_m = 0`. Después, app en el simulador (iPhone 17, ubicación Roma) con favoritos reales: orden, `BestFlag`, distancia y tiers correctos en pantalla.
- **Desempate por distancia** (a raíz de la verificación visual): dos favoritos empatados a 1,899 se ordenaban por orden de alta, dejando arriba el que estaba al doble de distancia. Contradice la pregunta que responde la hoja ("¿a cuál voy ahora?"). Corregido + test.
- Verdict: **APPROVED** tras remediación.

---

## Plan Iteration: PREMIUM-001 — Capa premium (pago único, sin ads) con StoreKit 2 — Completed
**Date:** 2026-09-01

### Architect (ADR-006)
- StoreKit 2 directo (sin RevenueCat) envuelto en `PurchaseClient` (`@Dependency`); no-consumible `com.danmarjim.fuelmap.premium.noads` (~€3,99). Favoritos siguen gratis e ilimitados (gancho de retención, no se capan).
- Entitlement se resuelve **antes** del flujo de consentimiento (UMP/ATT) en `AppFeature.onAppear`: premium no ve formulario GDPR ni prompt de tracking.
- Cache síncrona del entitlement (`LockIsolated<Bool>` + listener de `Transaction.updates`), mismo patrón que `LocationClient`.
- Hallazgo bloqueante resuelto en desarrollo: builds headless firman ad-hoc sin entitlements → StoreKit no da productos/compras. Se arregla con `FuelMap.entitlements` aplicado solo a simulador (`CODE_SIGN_ENTITLEMENTS[sdk=iphonesimulator*]`); en device/TestFlight los inyecta el provisioning profile.

### Developer (implementation)
- `Core/Purchases/{PurchaseClient,PurchaseStore}.swift`, `Features/Premium/{PaywallFeature,PaywallView}.swift`, `Features/Settings/SettingsView.swift` (hoja plana con callbacks, sin reducer propio — entry point + Ripristina acquisti + atribución IODL 2.0 + versión).
- `AppFeature`: `isPremium`/`bannerAdUnitID` en State; premium → sin `adUnitID`/consent/start; free → orden `adUnitID` → `requestConsent()` → `start()`. Guard de idempotencia en `entitlementChanged` (evita re-disparar consent/start si el stream repite el mismo valor).
- `StationDetailFeature`: `adUnitID` gateado por `purchaseClient.isPremium()`.
- `FuelMap.storekit` + `project.yml` (`storeKitConfiguration` en el scheme) — compra/cancela/reembolsa/restaura en simulador sin ASC ni PLA.
- Strings de paywall/settings localizadas it/es/en (verificado en el catálogo: 8/8 claves con las 3 locales).

### QA (tests)
- `PremiumTests`, `PurchaseStoreTests` (contra `.storekit` local), `PaywallFeatureTests`. **75 tests en 20 suites, todos verdes** (61 → 75). SwiftLint 0.
- Verificado en esta sesión (2026-09-01): `xcodegen generate` + `xcodebuild test` (iPhone 17 sim) → **TEST SUCCEEDED**, `swiftlint lint` → 0 violaciones.

### Review
- Límite de `SKTestSession` documentado: `refundTransaction` no propaga a `currentEntitlements` en simulador (test de reembolso vía sesión descartado a propósito; la conducta real se verifica por el listener en `AppFeature`, con test).
- **No verificado en esta sesión** (requiere Xcode + interacción manual, no headless): tap-through real del paywall (CTA → hoja de compra de Apple → banner desaparece) y compra en device con cuenta sandbox.
- Deuda de diseño conocida y aceptada: hueco vertical en el paywall en pantallas altas (cosmético, no bloquea).
- Verdict: **APPROVED**. Ver ADR-006.

---

## Plan Iteration: RELEASE-001 Fase 1 — Onboarding — Completed
**Date:** 2026-09-01

### Architect (decisiones tomadas en directo, ejecución sin PRD/RFC separado)
- 2 pantallas (no 3): bienvenida (propuesta de valor) + priming de ubicación. Se
  descartó la pantalla de selección de combustible planteada en `.claude/plan.md`
  para mantenerlo "sencillo, nada fancy" (pedido explícito del usuario) — el
  combustible por defecto ya es ajustable en `FiltersFeature` sin fricción.
- Sin pitch de premium en el onboarding (coherente con ADR-006: el onboarding vende
  la app, no la compra).
- Siempre saltable; sin paginación por swipe (un botón basta para 2 pasos).
- Flag `hasCompletedOnboarding` en `UserDefaults` vía `OnboardingStorage`
  (`@Dependency`, mismo patrón que el resto de clients), no SwiftData — es
  preferencia de app, no dato de dominio.
- **Decisión no obvia**: el consentimiento UMP/ATT (ya disparado desde
  `AppFeature.onAppear` para el entitlement premium) se **difiere** hasta que el
  onboarding termina — apilar el formulario GDPR sobre la pantalla de bienvenida
  habría sido la regresión de UX que este plan buscaba evitar. Cubierto con guards
  en `entitlementLoaded`/`entitlementChanged` + retomado en
  `.onboarding(.delegate(.finished))`.
- `LocationClient.requestWhenInUse` ya era idempotente (`guard current == .notDetermined`)
  → `MapFeature` no necesitó tocarse: si el onboarding ya pidió el permiso, la
  llamada de `MapFeature.onAppear` simplemente devuelve el estado actual sin
  relanzar el prompt del sistema.

### Developer (implementation)
- `Core/Onboarding/OnboardingStorage.swift` — `@Dependency` sobre `UserDefaults`.
- `Features/Onboarding/{OnboardingFeature,OnboardingView}.swift` — reducer de 2
  páginas + vista con el mismo lenguaje visual que `PaywallView` (hero circular +
  título + subtítulo + CTA), sin componentes ni animaciones propias.
- `AppFeature`: `showOnboarding`/`onboarding` en `State`; resuelto originalmente en
  `.onAppear` desde `onboardingStorage` (mismo patrón que el entitlement premium).
  **Superado por el fix de esta misma fase** (ver entrada "Fix — el permiso de
  ubicación se pedía de golpe..." más abajo): pasó al `init()`, síncrono. Guards en
  `entitlementLoaded`/`entitlementChanged` para diferir `enableAds` mientras
  `showOnboarding` es `true`.
- `AppView`: `Group` raíz que muestra `OnboardingView` a pantalla completa o el
  contenido normal (mapa + banner + sheets), según `showOnboarding`.
- 8 strings nuevas it/es/en en `Localizable.xcstrings` (insertadas preservando el
  formato exacto de Xcode — `" : "` con espacio — para no generar un diff de
  reformateo masivo del catálogo).
- `Delegate`/`Page` de `OnboardingFeature` viven al nivel del reducer, no anidados
  en `Action`/`State` (límite de anidamiento de SwiftLint, mismo patrón que
  `MapFeature.Delegate`).

### QA (tests)
- `OnboardingFeatureTests` (4): avance de página, skip sin tocar ubicación, activar
  ubicación pide permiso y termina, "no ahora" termina sin pedir permiso.
- `AppFeatureTests`: nuevo test de regresión para el diferido de ads/consent
  durante el onboarding (entitlement se resuelve pero no dispara `enableAds` hasta
  `.onboarding(.delegate(.finished))`).
- `OnboardingStorage.testValue.hasCompleted` devuelve `true` por defecto (para no
  romper los tests existentes que no son sobre onboarding); los tests de onboarding
  lo sobreescriben a `false` explícitamente.
- **80 tests en 21 suites, todos verdes** (75 → 80). SwiftLint 0. `xcodebuild test`
  (iPhone 17 sim): **TEST SUCCEEDED**.

### Review
- Build + tests + lint verificados en esta sesión tras el refactor de nesting
  (`Delegate`/`Page` sacados de `Action`/`State`) y el fix de línea larga con
  string multilínea en `OnboardingView`.
- **No verificado en simulador de forma interactiva** (headless): instalación
  limpia mostrando las 2 pantallas, skip funcional a ojo, y que el permiso de
  ubicación no se pide dos veces en un lanzamiento real. Recomendado antes de
  TestFlight (FM-14 ya incluye una verificación manual similar para el paywall).
- Verdict: **APPROVED** (pendiente de verificación visual manual, no bloqueante
  para seguir con la Fase 2 del plan).

### Iteración — navegación por swipe + page control animado (mismo día)
- **Petición del usuario**: permitir scroll horizontal como navegación y añadir un
  page control animado (los botones seguían siendo obligatorios).
- `OnboardingFeature.Page` pasa a `Hashable, CaseIterable` (requerido por
  `TabView(selection:)` y el `ForEach` del page control).
- **Unificación de acciones**: `continueTapped` se elimina en favor de un único
  `pageChanged(Page)` — el botón "Continua" y el swipe del `TabView` son el mismo
  gesto para el reducer, no dos conceptos distintos.
- `OnboardingView`: `TabView` con `.tabViewStyle(.page(indexDisplayMode: .never))`
  ligado a `store.page` vía `Binding` manual (envía `.pageChanged`); page control
  propio (cápsulas, no los puntos nativos) para mantener el lenguaje visual del
  design system — cápsula ancha + `brandPrimaryFill` en la página activa, punto
  `separator` en las demás, con `.spring` (respeta Reduce Motion). El footer
  también anima el cambio de botones entre páginas.
- Tests: `onboarding_continue_advancesToLocationPage` migrado a `.pageChanged`;
  nuevo `onboarding_swipeBack_returnsToWelcomePage` (mismo reducer, sin lógica
  nueva que probar más allá del cambio de página en cualquier dirección).
- **81 tests en 21 suites, todos verdes** (80 → 81). SwiftLint 0. Build verde.
- Verdict: **APPROVED** (verificación visual manual sigue pendiente, igual que la
  entrada anterior).

### Fix — el permiso de ubicación se pedía de golpe en el paso 1 (mismo día)
- **Reportado por el usuario** al probar en simulador: el alert de ubicación saltaba
  en la primera pantalla del onboarding, no en la segunda.
- **Causa raíz**: `showOnboarding` se inicializaba en `false` por defecto y solo se
  corregía dentro del reducer al procesar `.onAppear`. SwiftUI pinta `body` **antes**
  de que `.onAppear` llegue a ejecutarse, así que en el primer frame `AppView`
  renderizaba `mainContent` (con `MapView`) en vez de `OnboardingView`. El `onAppear`
  de `MapView` dispara `locationClient.requestWhenInUse()` de inmediato — de ahí el
  permiso "de golpe", visualmente superpuesto al primer frame del onboarding.
- **Fix**: `AppFeature.State` gana un `init()` propio que resuelve `showOnboarding`
  leyendo `onboardingStorage` de forma **síncrona** (es una lectura de `UserDefaults`
  sin red, no hay razón para diferirla como el entitlement de StoreKit). Ya no hay
  frame intermedio con el valor por defecto equivocado.
- **A petición del usuario**: se quita el botón "Non ora"/"Ahora no" del segundo
  paso — `enableLocationTapped` es ahora el único camino hacia adelante ahí (si el
  usuario deniega en el alert del sistema, el onboarding termina igual vía
  `.locationResponse`); retroceder a la bienvenida (swipe) y usar "Salta" sigue
  siendo la vía de escape completa.
- Tests: nuevo `appFeature_state_resolvesShowOnboardingSynchronouslyAtInit` (construye
  `AppFeature.State()` bajo `withDependencies` sin enviar ninguna acción — ancla la
  regresión exacta). `appFeature_firstLaunch_defersAdsUntilOnboardingFinishes`
  ajustado: ya no espera que `.onAppear` mute `showOnboarding` (viene del init).
  `onboarding_notNow_finishesWithoutRequestingPermission` eliminado (acción borrada).
- **81 tests en 21 suites** (mismo total: -1 test de `notNow`, +1 de regresión).
  SwiftLint 0. Build verde.
- Verdict: **APPROVED**.

---

## Plan Iteration: LOCATION-FALLBACK-001 — Plan para permiso de ubicación denegado — Completed
**Date:** 2026-09-01

### Contexto (pregunta de producto del usuario)
- "¿Qué ofrecemos a quien no acepta el permiso de ubicación?" — hoy la app caía en
  silencio a Roma sin explicar nada ni dar alternativa.
- Decisión de alcance con el usuario: dos partes, ambas en esta iteración —
  (1) banner + deep link a Ajustes (arreglo barato, reutiliza el fallback existente);
  (2) búsqueda manual de ciudad/dirección (la que de verdad sirve a quien nunca va a
  dar el permiso). No hubo pregunta de producto adicional: el orden y el alcance de
  cada parte se decidieron en la conversación previa.

### Parte 1 — Banner + Ajustes
- `MapFeature`: nuevo `locationPermissionDenied: Bool` + acción `locationPermissionDenied`
  (status `.denied`/`.restricted` en `onAppear`) — sigue cargando estaciones en Roma
  (`load(&state)`), pero ahora lo marca. Nueva acción `appBecameActive`: al volver a
  primer plano con el permiso antes denegado, reconsulta `authorizationStatus()` y
  recupera la ubicación real si el usuario lo concedió desde Ajustes (sin esto, el
  botón de Ajustes sería un callejón sin salida — volver a la app no habría hecho nada).
- `MapView`: `statusBar` gana una rama con CTA "Impostazioni" (`UIApplication
  .openSettingsURLString`); `@Environment(\.scenePhase)` dispara `appBecameActive`.
  El `banner(...)` helper gana un botón de acción opcional (antes solo título+icono).
- Prioridad de banners sin cambios de criterio: loading > error > **denegado** > vacío
  (denegado es contexto persistente, no debe tapar loading/error transitorios).

### Parte 2 — Búsqueda manual de ciudad/dirección
- **Decisión no obvia**: el botón de búsqueda queda visible siempre, no solo cuando
  el permiso está denegado — cualquier usuario puede querer mirar precios de otra
  ciudad (viaje, etc.), no es exclusivo del caso de fallback.
- `Core/Location/GeocodingClient.swift` (`@Dependency` nuevo): `search(query) async
  throws -> Coordinate` vía `MKLocalSearch`; `GeocodingError.noResults`.
- `MapFeature`: `locationSearchSubmitted(String)` / `locationSearchResponse(Result<...>)`;
  `isSearchingLocation` / `locationSearchError` en `State`. Éxito → centra el mapa,
  recarga estaciones, y **limpia `locationPermissionDenied`** (ya no tiene sentido
  seguir explicando "mostrando Roma" si el usuario acaba de elegir dónde mirar).
- `LocationSearchView.swift` (nueva): hoja con un campo + botón; se cierra sola al
  tener éxito (`onChange` de `isSearching`, sin nuevo estado ad-hoc). Botón de lupa
  añadido al stack de controles flotantes del mapa (junto a capas/settings).

### Refactor de tamaño (SwiftLint `type_body_length`, límite 250)
- `MapFeature.swift` superaba el límite tras añadir los casos nuevos → `load`/
  `loadFavoritePrices` extraídos a `MapFeature+Loading.swift` (mismo patrón que
  `MapFeature+Favorites.swift`); `CancelID` deja de ser `private` (visible entre
  archivos de la extensión).
- `MapFeatureTests.swift` superaba el límite → los tests de permiso/búsqueda se
  movieron a `LocationPermissionTests.swift` y `LocationSearchTests.swift` (mismo
  patrón que `FavoritePricesTests.swift`).

### QA (tests)
- `LocationPermissionTests` (4): denegado marca el banner y carga igual; restringido
  igual que denegado; volver de Ajustes con permiso ya concedido recupera ubicación
  y quita el banner; `appBecameActive` sin denegación previa no toca nada (dependencia
  `unimplemented` para probarlo).
- `LocationSearchTests` (3): búsqueda con éxito centra+carga+limpia el banner; sin
  resultados marca error sin tocar el centro (aserción por `!= nil`, no por string
  exacto — el runner puede correr en `es`, ver nota abajo); consulta en blanco no
  llama a la dependencia (`unimplemented`).
- Nota de aprendizaje: un test inicial comparaba `locationSearchError` contra el
  literal en italiano y falló porque el runner resolvió `String(localized:)` en
  español — mismo motivo por el que otros tests del repo (`map_stationsResponseFailure
  _setsError`) ya comprobaban solo `!= nil`. Corregido para seguir ese patrón.
- **87 tests en 23 suites, todos verdes** (81 → 87). SwiftLint 0. Build verde
  (iPhone 17 sim).

### Review
- No verificado en simulador de forma interactiva (headless): que el botón "Impostazioni"
  abra Ajustes de verdad, que volver de Ajustes con el permiso concedido recupere la
  ubicación en pantalla, y el flujo completo de búsqueda (teclado, resultado, cierre
  de hoja). Recomendado antes de TestFlight, acumulándose con las verificaciones
  manuales ya pendientes de onboarding y del paywall.
- Verdict: **APPROVED**.

### Parte 3 — Blur + tarjeta bloqueante (mismo día, a petición del usuario)
- **Cambio de dirección de producto**: "sin el permiso la app tiene poco sentido" →
  en vez de solo un banner discreto, difuminar el mapa entero con una tarjeta central
  hasta que exista **algún contexto de ubicación** (real o buscado a mano). Decisión
  explícita: las dos salidas (activar permiso / buscar ciudad) con el mismo peso
  visual — no es solo "empuja a dar el permiso", la búsqueda manual de Parte 2 sigue
  siendo una salida legítima, no un premio de consolación.
- `LocationPromptOverlay.swift` (nuevo): `Rectangle().fill(.ultraThinMaterial)` a
  pantalla completa + tarjeta centrada (icono + título + subtítulo + 2 botones).
  Sin reducer propio — puramente presentacional, gateada por `store.locationPermissionDenied`
  (ya probado en `LocationPermissionTests`; no necesita tests nuevos).
- **La tarjeta reemplaza, no complementa, el banner de Parte 1**: mostrar el aviso
  fino Y la tarjeta grande a la vez habría sido un mensaje duplicado. Se retira la
  rama `locationPermissionDenied` de `statusBar` y el `banner(...)` helper vuelve a
  su forma simple (sin `actionTitle`/`action`, que solo esa rama usaba).
- Strings huérfanas retiradas del catálogo (`Impostazioni`, `Mostrando Roma — attiva
  la posizione`) — la tarjeta reutiliza `"Attiva posizione"` (ya localizada, la misma
  copy que en el onboarding) y `"Cerca una città"` (ya localizada, título de la hoja
  de búsqueda) en vez de inventar botones nuevos. 2 strings nuevas: título y subtítulo
  de la tarjeta.
- El overlay se sitúa **después** de `.safeAreaInset(edge: .bottom)`: bloquea el mapa,
  los controles flotantes (lista/favoritos/capas/buscar/settings) **y** la barra de
  filtros inferior. Corrección a petición del usuario el mismo día: inicialmente el
  overlay iba antes del `safeAreaInset` y dejaba `FiltersView` fuera de su alcance —
  "no tiene sentido dejar ajustar filtros si no ve nada en pantalla". El orden de los
  modifiers en SwiftUI importa aquí: un `.overlay` aplicado después de
  `.safeAreaInset` cubre la vista compuesta completa (mapa + inset), no solo el mapa.

### QA (tests)
- Sin tests nuevos: el estado que gatea la tarjeta (`locationPermissionDenied`) ya
  está cubierto por `LocationPermissionTests`/`LocationSearchTests`; la vista en sí
  no tiene lógica propia que probar (mismo criterio que `OnboardingView`).
- **87 tests en 23 suites** (sin cambio de número — es un cambio de vista pura).
  SwiftLint 0. Build verde.

### Review
- No verificado en simulador de forma interactiva (headless): que el blur bloquee de
  verdad la interacción con el mapa/controles, que los dos botones de la tarjeta
  funcionen, y que desaparezca sola tras conceder el permiso o buscar con éxito.
  Se acumula con el resto de verificaciones manuales pendientes.
- Verdict: **APPROVED**.

---

## Plan Iteration: RELEASE-001 Fase 2 — Ads en producción — Completed
**Date:** 2026-09-01

### Contexto
- Cuenta AdMob creada por el usuario en esta sesión (app iOS "FuelMap", sin publicar
  aún — límites de servicio activos hasta enlazarla a una ficha de App Store en la
  Fase 4; no bloquea nada de lo de aquí). Guiado paso a paso: apps.admob.com → Add
  app (iOS, no publicada) → 2 ad units de banner (mapa/detalle) → Privacy & messaging
  (mensaje GDPR, requisito para que el UMP ya integrado tenga qué mostrar).

### Developer (implementation)
- **IDs reales**: `GADApplicationIdentifier` (`ca-app-pub-6310894186551423~8828201061`)
  y los 2 ad units (`.../4014858083` mapa, `.../9555141528` detalle) cableados.
  Bifurcación Debug/Release: `#if DEBUG` en `AdClient.swift` (TEST siempre en Debug,
  reales solo en Release — nunca reportar tráfico de desarrollo a la cuenta real);
  `GAD_APPLICATION_IDENTIFIER` en Info.plist vía `settings.configs.Release` de
  `project.yml` (mismo mecanismo, a nivel de build setting).
- **`SKAdNetworkItems`**: añadido con el ID de Google (`cstr6suwn9.skadnetwork`) —
  suficiente sin mediation (la app solo usa AdMob directo); ampliar la lista si se
  añaden redes de mediation en el futuro.
- **`PrivacyInfo.xcprivacy`** (nuevo): declara solo lo que el código de la app usa
  directamente (`UserDefaults` en `OnboardingStorage`, razón `CA92.1`) y los tipos de
  dato recogidos (ubicación precisa para funcionalidad, device ID para publicidad de
  terceros con `NSPrivacyTracking: true`). No declara el uso de GoogleMobileAds/UMP/
  Supabase — cada SDK trae su propio manifest, Apple los fusiona en build time.
  XcodeGen lo detectó solo como recurso (sin configuración adicional en `project.yml`).
- **Bloqueante no previsto**: AdMob exigió una URL de privacy policy para completar
  la configuración de la app — deuda ya anotada desde PREMIUM-001 (`LegalURLs`
  comentaba "Apple la exige para publicar", ahora también la exige AdMob). Resuelto
  en la misma sesión:
  - `docs/privacy-policy.html` (it/es/en en una página, sin JS ni dependencias
    externas) redactada a partir del comportamiento real de la app (sin cuentas,
    ubicación no persistida, favoritos solo locales, ads vía AdMob con consentimiento,
    compras vía StoreKit sin datos de pago propios, atribución MIMIT/IODL 2.0).
  - **Repo `Danmarjim/FuelMap` pasado a público** (decisión del usuario, confirmada
    explícitamente) para poder servir GitHub Pages desde `/docs` en el plan gratuito
    — verificado antes de cambiar la visibilidad que no hay secretos commiteados
    (solo la `anon key` de Supabase, documentada como segura para el cliente; la
    `service_role key` solo se referencia por nombre de variable de entorno, nunca
    su valor). Publicada en `https://danmarjim.github.io/FuelMap/privacy-policy.html`
    (verificado HTTP 200).
  - `LegalURLs.privacyPolicy` (nuevo) enlazado desde el paywall (junto al EULA) y
    desde la hoja de Ajustes (`SettingsView`, sección "legal" nueva) — visible para
    todo el mundo, no solo para quien abre el paywall.
- Commit `83f05a8` en `main`: **solo** `docs/privacy-policy.html` (el rename de
  `plan.md` a `plan-archive/PREMIUM-001.md`, ya en el índice de una sesión anterior,
  se coló en el mismo commit — sin impacto, era un movimiento pendiente de comitear
  igualmente). El resto del trabajo de esta sesión (onboarding, location-fallback,
  ads) sigue sin commitear, a la espera de que el usuario lo pida explícitamente.

### QA (tests)
- Sin tests nuevos: IDs/config no son lógica de dominio. Verificación por build:
  `xcodebuild build` en **Debug** (IDs de TEST) y **Release** (IDs reales) — ambos
  verdes; `strings` sobre el binario de Release confirma que los ad units reales
  quedan embebidos solo ahí, no en Debug. `plutil` sobre el Info.plist compilado
  confirma `GADApplicationIdentifier`/`SKAdNetworkItems` resueltos correctamente en
  cada configuración.
- **87 tests en 23 suites** (sin cambio — no hay reducers nuevos). SwiftLint 0.

### Review
- El `PrivacyInfo.xcprivacy` es un borrador razonado a partir de las categorías
  documentadas por Apple, no una revisión legal — anotado explícitamente en el
  propio archivo y aquí para que se revise antes de la submission (FM-14).
- No verificado en dispositivo/TestFlight (no disponible en esta sesión): que el
  banner real sirva impresiones de verdad (los límites de servicio de AdMob seguirán
  activos hasta enlazar la app en la Fase 4, así que el volumen real será bajo al
  principio de todos modos) y que el formulario UMP de producción cargue el mensaje
  GDPR configurado en la cuenta.
- Verdict: **APPROVED**.

---

## Plan Iteration: RELEASE-001 Fase 3 — Polish/HIG pass (ios-reviewer) + remediación — Completed
**Date:** 2026-09-01

### Architect (evaluación con agentes, según lo acordado en `workflow-mode`)
- `ios-reviewer` lanzado sobre el diff acumulado sin commitear de Onboarding +
  LOCATION-FALLBACK-001 + Ads producción, más la deuda diferida de RESTYLE-001
  (ring de elevación oscuro, dedup `separator`). Corrió `/simplify` primero (norma
  del proyecto). Informe completo: `.claude/reviews/2026-09-01-release-001-f1-f2-review.md`.
- Veredicto: **Changes Requested** — 3 críticos, 7 altos, 12 medios, 9 nits, 2 deuda
  RESTYLE-001 (ambas vivas). Arquitectura correcta, sin data races/force-unwraps/
  retain cycles nuevos; los defectos eran de flujo de producto y accesibilidad, no
  de diseño de fondo.

### Developer (remediación — todos los bloqueantes + varios no bloqueantes de bajo coste)
- **C-1** (el permiso salía sin priming al pulsar "Salta", y competía con UMP/ATT):
  `OnboardingFeature` unifica `skipTapped`/`enableLocationTapped` — ambos piden el
  permiso y terminan; `Delegate.finished` ahora lleva el `CLAuthorizationStatus`
  resuelto. `AppFeature` lo reenvía a `MapFeature` como `locationPermissionResolved`;
  `MapFeature.onAppear` ya no vuelve a llamar a `requestWhenInUse()` si el onboarding
  ya lo resolvió. Nuevo helper `resolveLocationEffect(for:)` (antes duplicado entre
  `.onAppear` y `appBecameActive`, reuso #5 del informe).
- **C-2** (`locationPermissionDenied` significaba tres cosas; una búsqueda manual
  dejaba `appBecameActive` sin salida): guard cambiado a `state.userLocation == nil`.
  El rediseño completo con un `enum LocationContext` queda como deuda de arquitectura
  (ver Altitud #18 del informe) — no se hizo aquí a propósito, es un cambio mayor.
- **C-3** (el blur bloqueante no bloqueaba VoiceOver): `.accessibilityHidden` sobre
  mapa+controles+filtros mientras el overlay está presente, `.accessibilityAddTraits(
  .isModal)` en la tarjeta.
- **A-1** (`.onAppear` de `AppFeature` no era idempotente): `didAppear` en `State`,
  mismo patrón que `MapFeature.didRequestLocation`.
- **A-2** (`SKAdNetworkItems` solo con el ID de Google): lista completa de ~50 IDs de
  la documentación de Google para AdMob (`developers.google.com/admob/ios/ios14`,
  consultada 09-01) en `project.yml`.
- **A-3** (CTA secundario del overlay, 2,92:1 en claro — no pasa WCAG AA): la
  corrección sugerida por el propio informe (`brandPrimary`) no cambiaba nada — es
  el mismo `#0091FF` que `brandTint` en claro, verificado en los colorsets. Se usó
  `brandPrimaryPressed` (#005BB8, 5,93:1) en su lugar.
- **A-4** (dos interruptores Debug/Release para la misma decisión de ads): única
  fuente de verdad en `project.yml` (`GAD_BANNER_UNIT_ID`/`GAD_DETAIL_UNIT_ID` por
  config → `FuelMapBannerAdUnitID`/`FuelMapDetailAdUnitID` en Info.plist,
  `AdClient` los lee de ahí). El `#if DEBUG` desaparece.
- **A-5** (Dynamic Type de accesibilidad recortaba las 3 vistas nuevas): `ScrollView`
  en `OnboardingView`/`LocationPromptOverlay`/`LocationSearchView`. No se hizo el
  "badge adaptativo" que también sugería el informe — el recorte era el problema
  real, el tamaño del icono es cosmético.
- **A-6** (cualquier fallo de geocoding se leía como "no hay resultados"):
  `GeocodingError` gana `.network` con mensaje distinto.
- **A-7 + M-1** (deep link a Ajustes fuera del reducer; hoja de búsqueda cerrada por
  inferencia): `.openLocationSettingsTapped` vía `@Dependency(\.openURL)`;
  `isShowingLocationSearch` pasa a `MapFeature.State`, se cierra explícitamente en
  `.success`.
- **M-3, M-6, M-7, M-10**: detents `[.medium, .large]` en la búsqueda; "Salta" ahora
  se renderiza condicionalmente (no `.opacity(0)`, que dejaba el botón en el árbol de
  accesibilidad) — ya no se muestra en la página 2 porque, tras C-1, "Attiva
  posizione" hace exactamente lo mismo; `nilIfEmpty` unifica el criterio de trim
  entre vista y reducer; `CancelID.locationSearch` sustituye al `SearchCancelID`
  duplicado.
- **M-5**: page control expuesto a VoiceOver (`accessibilityValue` "1 di 2"/"2 di 2"),
  punto inactivo pasa de `separator` (1,40:1) a `textTertiary` (3,13:1).
- **M-4** (parcial): el botón de búsqueda lleva `accessibilityLabel` fijo ("Cerca")
  aunque muestre un `ProgressView` sin texto. No se implementó el anuncio de
  accesibilidad del error (`AccessibilityNotification.Announcement`) — queda como
  deuda menor.
- **M-11**: `PrivacyInfo.xcprivacy` pasa de `PreciseLocation` a `CoarseLocation`
  (coherente con `kCLLocationAccuracyHundredMeters`).
- **D-1** (ring de elevación en oscuro, deuda de RESTYLE-001): `elevation(_:in:)`
  nuevo en `Elevation.swift` — añade un `strokeBorder` en oscuro sobre la misma forma
  del fondo. Aplicado a la tarjeta de `LocationPromptOverlay`, el banner de estado y
  el chrome de los controles flotantes del mapa. No aplicado a los pins (ya tienen
  su `strokeBorder` de tier) ni al pill de filtros (`.e1`, decorativo, bajo riesgo).
- **D-2** (dedup `separator`, deuda de RESTYLE-001): `HairlineDivider` en
  `SheetComponents.swift`, sustituye las 6 copias (`AppView`, `StationDetailView`×2,
  `FavoritesView`, `StationListView`, `PaywallView`).
- **Reuso #6**: `LegalLinksRow` sustituye las dos filas de enlaces legales
  duplicadas (orden y estilo distintos) de `PaywallView`/`SettingsView`.
- **Nit #8**: reconciliada la entrada de PHASE_LOG de Fase 1 que seguía diciendo que
  `showOnboarding` se resolvía en `.onAppear` (la corrección real quedó en una
  entrada de "Fix" posterior).
- **Diferido a propósito** (documentado, no bloqueante): rediseño con
  `enum LocationContext` (Altitud #18); `FMButtonStyle`/`BrandIconBadge` compartidos
  (reuso #1/#2); `SheetEmptyState` con slot de acciones en vez de que
  `LocationPromptOverlay` reimplemente su propia tarjeta (reuso #3); anuncio de
  accesibilidad del error de búsqueda (M-4 parcial); `@Shared(.appStorage(...))` en
  vez de `OnboardingStorage` propio (Altitud #19); helpers de simplificación #8-#17
  del informe (no afectan corrección).
- `MapFeature.swift` volvió a superar el límite de 400 líneas (`file_length`) tras
  los nuevos casos → `MapDefaults`/`MapStyleOption`/`StationSort` extraídos a
  `MapTypes.swift`.

### QA (tests)
- Tests existentes actualizados por los cambios de contrato: `OnboardingFeatureTests`
  (`Delegate.finished` ahora lleva status; skip también pide permiso),
  `AppFeatureTests`/`PremiumTests` (`didAppear` en los `send(.onAppear)` exhaustivos),
  `LocationPermissionTests` (el guard de `appBecameActive` cambió de campo).
- Tests nuevos, todos anclando un hallazgo concreto del informe: segundo `.onAppear`
  no-op (A-1), `setCompleted()` se llama al terminar el onboarding (M-12),
  `appBecameActive` tras búsqueda manual sigue recuperando ubicación real (C-2),
  fallo de red se reporta como error de conexión (A-6), abrir/cerrar la hoja de
  búsqueda limpia el error y la presentación la posee el reducer (M-1),
  `openLocationSettingsTapped` abre la URL correcta vía `openURL` (A-7).
- **95 tests en 23 suites, todos verdes** (87 → 95). SwiftLint 0. Build Debug **y**
  Release verdes (iPhone 17 sim).

### Review
- Aprendizaje de proceso: un `store.finish()` sin ningún `store.receive()` explícito
  no bastó para que `AppFeatureTests.appFeature_firstLaunch_defersAdsUntilOnboardingFinishes`
  reflejara el estado final de una acción reenviada a `MapFeature` vía `.merge` —
  hubo que añadir `store.receive()` explícitos para las tres acciones en cascada.
  Quedó así en el test final: más verboso, pero determinista.
- No verificado en simulador de forma interactiva (headless), acumulado con lo
  pendiente de fases anteriores: que "Salta" ya no dispare el permiso sin priming,
  que el blur bloquee de verdad a VoiceOver, que volver de Ajustes tras una búsqueda
  manual recupere la ubicación real, y el resto de verificaciones visuales ya
  anotadas en el Current State.
- Verdict tras remediación: **APPROVED**.

---

## Current State
**Date:** 2026-09-01
- **Restyle visual completo aplicado** (RESTYLE-001, design system "bold/energetic" azul): tokens semánticos claro/oscuro, tiers daltónico-seguros, pins/cluster/chrome nuevos + **control de capas**, barra de filtros, sheets (lista/favoritos/detalle), skeletons, Reduce Motion, Dynamic Type capada en pin. Referencia: `.claude/design/`, ADR-005.
- **Capa premium entregada** (PREMIUM-001, 09-01): pago único (~€3,99) sin ads vía StoreKit 2 directo; paywall + hoja de ajustes; entitlement resuelto antes de UMP/ATT. Ver ADR-006. Falta la acción del usuario en ASC (aceptar PLA + crear el IAP) antes de TestFlight/producción.
- **Onboarding entregado** (RELEASE-001 Fase 1, 09-01): 2 pantallas (valor + priming de ubicación), navegables por swipe (`TabView` paginado) o botón, con page control animado (cápsulas) y siempre saltable; sin pitch de premium. El consentimiento UMP/ATT se difiere hasta que el onboarding termina (evita apilar el formulario GDPR sobre la bienvenida). `showOnboarding` se resuelve en el `init()` de `AppFeature.State` (síncrono) tras un bug reportado por el usuario (se pedía el permiso de golpe en el paso 1 por una condición de carrera con el primer frame de SwiftUI). Falta verificación visual manual en simulador (no bloqueante).
- **Plan para permiso de ubicación denegado** (LOCATION-FALLBACK-001, 09-01): sin contexto de ubicación (ni permiso ni ciudad buscada), el mapa se difumina con una tarjeta bloqueante que ofrece **activar permiso** (Ajustes, `appBecameActive` recupera la ubicación al volver) o **buscar una ciudad** (`GeocodingClient` vía `MKLocalSearch`, salida con el mismo peso, no un consuelo) con el mismo peso visual. El botón de búsqueda queda además disponible siempre en el chrome del mapa, no solo en la tarjeta. Falta verificación visual manual (Ajustes real + blur bloqueando interacción + flujo de búsqueda completo).
- **Ads en producción** (RELEASE-001 Fase 2, 09-01): cuenta AdMob real creada, App ID + 2 ad units cableados (TEST en Debug / reales en Release, única fuente de verdad en `project.yml` tras la remediación de Fase 3 — ya no `#if DEBUG`), `SKAdNetworkItems` (lista completa de Google), `PrivacyInfo.xcprivacy`. Bloqueante no previsto resuelto: **privacy policy publicada** en `https://danmarjim.github.io/FuelMap/privacy-policy.html` (repo pasado a público para servir GitHub Pages, sin secretos expuestos) y enlazada desde Ajustes + paywall (`LegalLinksRow` compartido). Falta verificar banner real en device/TestFlight y que el UMP cargue el mensaje GDPR configurado en AdMob.
- **Polish/HIG pass + remediación** (RELEASE-001 Fase 3, 09-01): `ios-reviewer` sobre todo el diff del día → 3 críticos (permiso sin priming al saltar el onboarding, `appBecameActive` roto tras búsqueda manual, blur bloqueante invisible para VoiceOver) + 7 altos, todos remediados. De paso se cerró la deuda diferida de RESTYLE-001 (ring de elevación en oscuro, dedup `separator`). Informe: `.claude/reviews/2026-09-01-release-001-f1-f2-review.md`.
- iOS: **95 tests** (23 suites), SwiftLint 0. Build verde en Debug y Release (iPhone 17 sim). Repo `Danmarjim/FuelMap` **público** desde hoy; commit `83f05a8` en `main` (solo la privacy policy) — el resto de la sesión (onboarding, location-fallback, ads, remediación) sigue sin commitear. ADRs 001–006.
- **Backend sync endurecido** (06-09): `download()` con retry+timeout; workflow en actions v5. Cron diario verde, ~23.7k stations / ~92k prices por run.
- **App icon entregado** (APPICON-001, 07-17): surtidor blanco sobre azure con display oro y € (gasolinera héroe + € = ahorro). Fuente SVG en `.claude/design/appicon/`; el PNG del catálogo se genera desde ahí. Tacha una dependencia de FM-14.
- **Favoritos con precio en vivo** (FAV-PRICE, 07-17): la hoja ordena por precio (desempate por distancia), marca el más barato y muestra distancia + tier; refresca al cambiar de combustible. Salda la deuda de RESTYLE-001 R4/R6. **`0004_stations_by_ids.sql` aplicada en Supabase y verificada end-to-end en simulador.** Zoom inicial del mapa a ≈5 km (`MapDefaults.span` 0.02).
- Issues de producto: hechos FM-1…FM-13, FM-15…FM-19, PREMIUM-001, RELEASE-001 Fases 1-3 (Onboarding, Ads producción, Polish/HIG), LOCATION-FALLBACK-001. **Restante: FM-14** (App Store prep) + Fase 4 del roadmap de release (ver `.claude/plan.md`).
- **Pendiente usuario:** aplicar `0002_station_detail.sql` si no estaba (aplicarlo **antes** que `0003_expose_fuel_raw.sql`, que hace drop+recreate de las RPC); aceptar PLA Apple (device/TestFlight/IAP); crear el no-consumible en App Store Connect; completar verificación de cuenta AdMob (datos de pago, cuando quiera cobrar de verdad); verificar visualmente en simulador/device el onboarding, el flujo de permiso denegado/búsqueda manual, y el banner real de ads.
- **Próximo paso:** RELEASE-001 Fase 4 (`.claude/plan.md`) — App Store submission prep (FM-14): Info.plist l10n, App Privacy en ASC, metadata, capturas, TestFlight, verificar compra real. España queda fuera del release v1 (fast-follow v1.1, ver `.claude/prd/PRD-002-espana.md` cuando exista). Deuda diferida a propósito (documentada en la review de Fase 3): `enum LocationContext` unificado, `FMButtonStyle`/`BrandIconBadge` compartidos, anuncio de accesibilidad del error de búsqueda; `stations_by_ids` sin `fuel_raw` (irrelevante hoy); Info.plist aún solo en italiano (usage strings) — entra en FM-14; `PrivacyInfo.xcprivacy` es borrador razonado, revisar antes de submission.

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
