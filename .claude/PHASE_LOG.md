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
- `MapFeature`: `favoriteStations` + `isLoadingFavoritePrices` en State; efecto `loadFavoritePrices` cancelable (`CancelID.favoritePrices`), disparado tras `favoritesResponse` y **fusionado con `load` en cualquier cambio de filtro**. Sin favoritos no hay red. Derivados: `favoriteDisplays` (orden por precio asc, sin precio al final, desempate por orden de alta), `cheapestFavoriteID`, `favoritePriceTiers`.
- `FavoritesView`: filas con distancia, precio, `TierTag`, `BestFlag` en el más barato y nota "n/d" si el favorito no vende el combustible activo. VoiceOver compone nombre + distancia + precio + tier. Skeleton solo en la **primera** carga; en refrescos conserva los precios previos.
- Fallo de red **silencioso**: la hoja sigue usable por nombre/distancia en vez de vaciarse.
- Colado en el mismo commit (no es de FAV-PRICE): `MapDefaults.span` **0.08 → 0.02** — zoom inicial ≈5 km, menos pines a la vista.
- Commits: `7f38897` (feature) + `d9b0f2b` (remediación de review).

### QA (tests)
- `FavoritePricesTests.swift` (nuevo, 4 tests): carga + fetch de precios · sin favoritos no toca la API (`stationsByIDs` queda `unimplemented`, falla el test si se llama) · orden por precio con el "no disponible" al final · cambio de combustible refresca (Esso sin GPL → sin precio).
- `MapFeatureTests`: `clusterTapped` ahora asienta sobre `MapDefaults.span` en vez del literal.
- **60 tests en 17 suites, todos verdes** (57 → 60). SwiftLint **0**. `xcodebuild test` (iPhone 17 sim): **TEST SUCCEEDED**.

### Review
- **Colisión de migraciones**: la RPC entró como `0003_stations_by_ids.sql` con `0003_expose_fuel_raw.sql` ya ocupando ese número → renumerada a `0004`. El orden de aplicación manual en el SQL editor es la única garantía de secuencia; dos `0003` la rompen.
- **Regresión de lint**: los 4 tests nuevos llevaron `MapFeatureTests` a 285 líneas (`type_body_length`, límite 250) rompiendo el SwiftLint 0 del repo → extraídos a `FavoritePricesTests`.
- `stations_by_ids` **no devuelve `fuel_raw`** (sí lo hacen las RPC tocadas por `0003_expose_fuel_raw`). No rompe: `NearbyStationRowDTO.fuelRaw` es opcional y `StationMapper` cae a `row.fuel`. La hoja de favoritos muestra el precio más barato, no la variante — sin impacto visible. Añadir la columna si algún día la hoja muestra variante real.
- Verdict: **APPROVED** tras remediación.

---

## Current State
**Date:** 2026-07-17
- **Restyle visual completo aplicado** (RESTYLE-001, design system "bold/energetic" azul): tokens semánticos claro/oscuro, tiers daltónico-seguros, pins/cluster/chrome nuevos + **control de capas**, barra de filtros, sheets (lista/favoritos/detalle), skeletons, Reduce Motion, Dynamic Type capada en pin. Referencia: `.claude/design/`, ADR-005.
- iOS: **60 tests** (17 suites), SwiftLint 0. Build verde (iPhone 17 sim). Repo `Danmarjim/FuelMap` al día. ADRs 001–005.
- **Backend sync endurecido** (06-09): `download()` con retry+timeout; workflow en actions v5. Cron diario verde, ~23.7k stations / ~92k prices por run.
- **App icon entregado** (APPICON-001, 07-17): surtidor blanco sobre azure con display oro y € (gasolinera héroe + € = ahorro). Fuente SVG en `.claude/design/appicon/`; el PNG del catálogo se genera desde ahí. Tacha una dependencia de FM-14.
- **Favoritos con precio en vivo** (FAV-PRICE, 07-17): la hoja ordena por precio, marca el más barato y muestra distancia + tier; refresca al cambiar de combustible. Salda la deuda de RESTYLE-001 R4/R6. Zoom inicial del mapa a ≈5 km (`MapDefaults.span` 0.02).
- Issues de producto: hechos FM-1…FM-13, FM-15…FM-19. **Restante: FM-14** (App Store prep).
- **Pendiente usuario (bloquea favoritos en producción):** aplicar `0004_stations_by_ids.sql` en el SQL editor de Supabase — sin él, `stationsByIDs` falla y la hoja cae al modo degradado (nombre/distancia, sin precio). También `0002_station_detail.sql` si no estaba; aceptar PLA Apple (device/TestFlight).
- **Próximo paso:** FM-14 (IDs AdMob reales, SKAdNetwork, privacy labels, Info.plist l10n, IODL2, TestFlight). Deuda menor: ring de elevación en oscuro (M-4), dedup `separator`; `stations_by_ids` sin `fuel_raw` (irrelevante hoy).

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
