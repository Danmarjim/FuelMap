# System Map — FuelMap

> Module map and key file reference. Agents read from here to navigate the codebase without loading the entire repo.
> Last updated: 2026-09-01 (RELEASE-001 Fase 3 — polish/HIG + remediación review)

## Design System layer

**Path:** `FuelMap/DesignSystem/` + `FuelMap/Assets.xcassets/Colors/` (tokens) · fuente de verdad en `.claude/design/`.

| File | Type | Responsibility |
|---|---|---|
| `Assets.xcassets/Colors/*.colorset` | tokens | 35 Color sets semánticos claro/oscuro (brand, surfaces, text, lines, price tiers, functional, `goldInk`). Tiers *fill* = valor único (mode-independent). `Color(.brandPrimary)`. |
| `DesignSystem/Spacing.swift` | enum | Escala 4pt (`s1`…`s10`). |
| `DesignSystem/Radius.swift` | enum | Radios sm/md/lg/xl/pill. |
| `DesignSystem/Elevation.swift` | modifier | `.elevation(.e1/.e2/.e3/.pin/.pinSelected/.sheet)`; profundiza en oscuro. `.elevation(_:in:)` añade además el hairline de contraste en oscuro sobre la forma dada — superficies planas sin borde propio (RESTYLE-001 D-1, RELEASE-001 F1-F2). |
| `DesignSystem/Typography.swift` | ext Font | Roles SF Pro mapeados a text styles (Dynamic Type) + fuentes de precio tabulares. |
| `DesignSystem/TokenGallery.swift` | View (#Preview) | Galería de validación de la paleta claro/oscuro. |
| `Features/Map/SheetComponents.swift` | Views | `TierTag`, `BestFlag`, `SortPill`, `SheetHeader`, `SheetEmptyState`, `FreshnessPill`, `StationRow` (con `unavailableNote` para filas sin precio), `SkeletonRow/List` + `shimmer()`, `HairlineDivider` (RESTYLE-001 D-2, RELEASE-001 F1-F2). |

> **En construcción.** Esqueleto TCA en marcha (FM-1). Las tablas marcadas `<!-- VERIFY -->` se rellenan conforme se implementan sus issues.

## Tooling del proyecto

| Archivo | Responsibility |
|---|---|
| `project.yml` | Spec XcodeGen: target iOS 17, Swift 6 strict concurrency, paquete SPM TCA. Genera `FuelMap.xcodeproj` (no commiteado). `GAD_APPLICATION_IDENTIFIER` bifurcado por `settings.configs.Release` (RELEASE-001 F2). |
| `FuelMap/PrivacyInfo.xcprivacy` | Manifest de privacidad del target (RELEASE-001 F2) — borrador razonado, revisar antes de submission (FM-14). |
| `docs/privacy-policy.html` | Privacy policy it/es/en, servida vía GitHub Pages (`https://danmarjim.github.io/FuelMap/`) — repo público desde 09-01 (RELEASE-001 F2). |
| `FuelMap/App/FuelMapApp.swift` | `@main` App; crea el `Store` raíz (inline, a promover en FM-7). |
| `FuelMap/App/AppFeature.swift` | Reducer raíz (esqueleto). Compondrá Map/Filters/Detail. |
| `FuelMap/App/AppView.swift` | Vista raíz; placeholder `ContentUnavailableView`, alojará `MapView` (FM-7). |
| `FuelMapTests/AppFeatureTests.swift` | Swift Testing; smoke del `AppFeature` con `TestStore`. |

## Target Module Overview (TCA)

```
App (FuelMapApp, root Store)
    ↓
Features (Reducers + Views)
    ├── Map/            MapFeature + MapView
    ├── StationDetail/  StationDetailFeature + StationDetailView
    └── Filters/        FiltersFeature + FiltersView
    ↓ (uses @Dependency)
Core/
    ├── Network/        APIClient (Supabase), DTOs
    ├── Location/       LocationClient (CoreLocation wrapper)
    ├── Ads/            AdClient (AdMob)
    └── Models/         Station, Price, FuelType (domain models)
```

---

## Features Layer

**Path:** `FuelMap/Features/` *(a crear)*

| File | Type | Responsibility |
|---|---|---|
| `Resources/Localizable.xcstrings` | String Catalog | Strings UI en it (fuente) + es + en (FM-13). |
| `App/AppFeature.swift` | Reducer | Raíz; `Scope` a `MapFeature` (FM-7); `onAppear`→consent+start ads (FM-11). |
| `App/AppView.swift` | View | Raíz; `MapView` + `BannerAdView` debajo (fuera del mapa) (FM-7/FM-11). |
| `Core/Ads/AdClient.swift` | `@Dependency` | `start`/`requestConsent` (UMP→ATT)/`bannerAdUnitID` (TEST); `AdConsentCoordinator` (FM-11). |
| `Core/Ads/BannerAdView.swift` | UIViewRepresentable | `GADBannerView` (banner AdMob) (FM-11). |
| `Map/MapFeature.swift` | Reducer | State del mapa; permisos→ubicación, carga con debounce/cancelación, guard de jitter, `@Presents detail`, error, `mapStyle` (capas, R2). Precios en vivo de favoritos: `favoriteStations` + efecto cancelable, refresco al cambiar filtro (FAV-PRICE). `locationPermissionDenied` + `appBecameActive` (guard por `userLocation == nil`, no por `locationPermissionDenied` — review C-2) + `locationPermissionResolved` (recibido del onboarding, no vuelve a pedir el permiso — review C-1) + `isShowingLocationSearch` (el reducer posee la presentación — review M-1) (LOCATION-FALLBACK-001, RELEASE-001 F1-F2). |
| `Map/MapTypes.swift` | tipos | `MapDefaults`/`MapStyleOption`/`StationSort`, extraídos de `MapFeature.swift` por `file_length` (RELEASE-001 F1-F2). |
| `Map/MapFeature+Loading.swift` | efectos | `load`/`loadFavoritePrices` extraídos del reducer principal (`type_body_length`) (LOCATION-FALLBACK-001). |
| `Map/MapFeature+LocationSearch.swift` | efectos | Búsqueda manual de ciudad/dirección (`geocodingClient`): centra el mapa, limpia `locationPermissionDenied` si estaba activo, mensaje si no hay resultados (LOCATION-FALLBACK-001). |
| `Map/MapFeature+Favorites.swift` | derivados | `favoriteDisplays` (precio asc, desempate por distancia, sin precio al final), `cheapestFavoriteID`, `favoritePriceTiers` + `FavoriteDisplay` (lleva `distance` ya calculada) (FAV-PRICE). |
| `Map/MapView.swift` | View | `Map` iOS 17+, annotations de precio, `onMapCameraChange`, recentrado (Reduce Motion), `.mapStyle`, status banner flotante (loading/error/vacío) + float controls (lista/favoritos/capas/buscar/settings); `scenePhase` dispara `appBecameActive` (R2, LOCATION-FALLBACK-001). |
| `Map/LocationSearchView.swift` | View | Hoja de búsqueda manual (campo + botón); la presentación la posee `MapFeature` (`isShowingLocationSearch`), no un `@Environment(\.dismiss)` local. `ScrollView` para tamaños de accesibilidad; botón con `accessibilityLabel` fijo (LOCATION-FALLBACK-001, RELEASE-001 F1-F2). |
| `Map/LocationPromptOverlay.swift` | View | Blur + tarjeta bloqueante sin contexto de ubicación: activar permiso o buscar ciudad, mismo peso visual. Cubre mapa, controles flotantes y barra de filtros (se aplica tras `.safeAreaInset`); `.accessibilityAddTraits(.isModal)` + `ScrollView`; sin reducer propio (LOCATION-FALLBACK-001, RELEASE-001 F1-F2). |
| `Map/MapClustering.swift` | lógica | `MapItem`/`StationCluster` + grid clustering por zoom (ADR-004, FM-15). |
| `Map/ClusterPin.swift` | View | Cluster: burbuja `surfaceElevated` + cápsula `da X` con tier de la más barata (R2). |
| `Map/PriceTiers.swift` | lógica | Terciles → `PriceTier` con `fill`/`ink`/`surface` + `symbolName` (▲●▼) + `label` localizada (daltónico-seguro, R1). |
| `Map/BrandStyle.swift` | lógica | Normaliza `Bandiera`→marca (color+monograma+asset+`logoBackground`) (FM-16). |
| `Map/BrandBadge.swift` | View | Chip de marca: logo sobre `logoBackground` o monograma/pompa neutro (R2). |
| `Map/StationPin.swift` | View | Pin: cápsula de tier + badge + forma de tier + precio + cola + halo; seleccionado/más barata; Reduce Motion + Dynamic Type capada (R2/R5). |
| `Map/StationListView.swift` | View | Hoja: header + sort pills + `StationRow` (chip, best-flag, precio, tier-tag); skeleton de carga; estado vacío (R4/R5). |
| `Map/FavoritesView.swift` | View | Hoja de favoritos con precio en vivo: consume `FavoriteDisplay` ya ordenado (no calcula distancias), `BestFlag` en el más barato, distancia + `TierTag`, "n/d" si no vende el combustible activo; skeleton en la 1ª carga; estado vacío (R4/FAV-PRICE). |
| `Filters/FiltersFeature.swift` | Reducer | `BindingReducer`; estado `fuel`/`selfOnly`/`radiusKm`. `RadiusOption` (FM-8). |
| `Filters/FiltersView.swift` | View | Barra: segmentado combustible + toggle Self + stepper radio + sort pills; fondo degradado (R3). |
| `StationDetail/StationDetailFeature.swift` | Reducer | Carga detalle completo (`stationDetail`); deep link Apple Maps (`openURL`); `dismiss` (FM-9). |
| `StationDetail/StationDetailView.swift` | View | Hoja: hero + precios por variante (Self/Servito, filtrado destacado), `FreshnessPill`, CTA Indicazioni→selector de navegación (R4). |
| `StationDetail/NavApp.swift` | enum | Apple/Google/Waze: deep links de indicaciones + probe de instalación (FM-17). |
| `Settings/SettingsView.swift` | View | Hoja plana (sin reducer propio, callbacks) desde float control (gear) en `MapView`: entry point al paywall, Ripristina acquisti, atribución IODL 2.0, sección legal (Privacy/Condizioni), versión (PREMIUM-001, RELEASE-001 F2). |
| `Onboarding/OnboardingFeature.swift` | Reducer | 2 páginas (bienvenida/ubicación); `pageChanged(Page)` unifica swipe y botón. `skipTapped`/`enableLocationTapped` piden permiso por igual — `Delegate.finished(CLAuthorizationStatus)` lleva el status resuelto para que `MapFeature` no lo vuelva a pedir (review C-1); sin pitch de premium (RELEASE-001 F1, F1-F2). |
| `Onboarding/OnboardingView.swift` | View | `TabView` paginado (swipe) + page control propio (cápsulas animadas, respeta Reduce Motion); mismo lenguaje visual que `PaywallView` (hero circular + título + subtítulo + CTA) (RELEASE-001 F1). |
| `Premium/PaywallFeature.swift` | Reducer | Estados loading/error+retry/purchasing/pending/success; precio desde `product.displayPrice` (nunca hardcodeado); restore obligatorio (ADR-006, PREMIUM-001). |
| `Premium/PaywallView.swift` | View | Propuesta de valor + CTA compra + restore + `LegalLinksRow` (`LegalURLs`: EULA + privacy policy, `docs/privacy-policy.html` vía GitHub Pages; componente compartido con `SettingsView`, antes duplicado — review reuso #6); `#Preview` por estado (PREMIUM-001, RELEASE-001 F1-F2). |

---

## Core Layer

**Path:** `FuelMap/Core/` *(a crear)*

| File | Type | Responsibility |
|---|---|---|
| `Models/Station.swift` | struct | Modelo de dominio de impianto; `cheapest` deriva el precio mínimo (FM-4). |
| `Models/FuelPrice.swift` | struct | Precio por combustible: `fuel`, `price` (Decimal 3 dec.), `isSelf`, `communicatedAt` (FM-4). |
| `Models/FuelType.swift` | enum | benzina/gasolio/gpl/metano/hvo/altro; rawValue = normalización backend (ADR-003, FM-4). |
| `Models/Coordinate.swift` | struct | Coordenada validada; `validated()` (NF6, FM-4); `distance(to:)` haversine (FM-10). |
| `Network/DTOs/NearbyStationRowDTO.swift` | Decodable | Fila plana de la RPC `nearby_stations` (RFC §3.1, FM-4). |
| `Network/DTOs/StationMapper.swift` | enum | Agrupa filas por estación → `[Station]`; descarta coords inválidas, normaliza fuel (FM-4). |
| `Network/DTOs/JSONDecoder+FuelMap.swift` | ext | Decoder compartido: convertFromSnakeCase + fechas ISO8601 (FM-4). |
| `Network/DTOs/ISO8601.swift` | enum | Parseo ISO8601 tolerante a fracciones de segundo (FM-4). |
| `Foundation/Decimal+Rounding.swift` | ext | `rounded(_:mode:)` para precios a 3 decimales (FM-4). |
| `Foundation/Decimal+FuelPrice.swift` | ext | `fuelPriceLabel` ("1,879 €"); formateo de precio compartido (review). |
| `Foundation/String+NilIfEmpty.swift` | ext | `nilIfEmpty` para campos vacíos del MIMIT (FM-4). |
| `Location/Coordinate+CoreLocation.swift` | ext | `clLocationCoordinate` + `init(_ CLLocationCoordinate2D)` compartidos (review). |
| `Network/APIClient.swift` | `@Dependency` | `nearbyStations`/`stationDetail`/`stationsByIDs` async; `APIError` tipado. `liveValue` = `.live()` (Supabase), `previewValue` = `.mock()`, `testValue` unimplemented (FM-5/FAV-PRICE). |
| `Network/APIClient+Live.swift` | impl real | RPC `nearby_stations`/`station_detail`/`stations_by_ids` vía supabase-swift; decode `JSONDecoder.fuelMap` + `StationMapper` (FM-5/FAV-PRICE). |
| `Network/SupabaseConfig.swift` | config | URL + anon key (read-only/RLS) + `SupabaseClient` compartido (FM-5). |
| `Network/APIClient+Mock.swift` | mock + fixtures | `APIClient.mock()` (previews/tests); `StationFixtures` (6 estaciones de Roma) (FM-5). |
| `Location/LocationClient.swift` | `@Dependency` | Wrapper CoreLocation (coordinador `@MainActor` + `LockIsolated` para status síncrono); `authorizationStatus`/`requestWhenInUse`/`currentLocation`; `LocationError` (FM-6). |
| `Location/GeocodingClient.swift` | `@Dependency` | Búsqueda de lugares por texto libre vía `MKLocalSearch`; `search(query) -> Coordinate`; `GeocodingError.noResults` (LOCATION-FALLBACK-001). |
| `Ads/AdClient.swift` | `@Dependency` | Integración AdMob banner + UMP/ATT; `bannerAdUnitID`/`detailAdUnitID` leídos del Info.plist (`FuelMapBannerAdUnitID`/`FuelMapDetailAdUnitID`, bifurcados por config en `project.yml` — única fuente de verdad, ya no `#if DEBUG` tras review A-4) (FM-11, RELEASE-001 F1-F2). |
| `Purchases/PurchaseClient.swift` | `@Dependency` | StoreKit 2: `premiumProduct`/`purchase`/`restore`/`isPremium` (síncrono, cacheado)/`refreshEntitlement`/`entitlementUpdates`. `PurchaseError` tipado. `liveValue` StoreKit 2 · `previewValue` free+mock · `testValue` unimplemented (ADR-006, PREMIUM-001). |
| `Purchases/PurchaseStore.swift` | actor/coordinador | `LockIsolated<Bool>` + listener `Transaction.updates`; arranca en `.task` raíz (PREMIUM-001). |
| `Onboarding/OnboardingStorage.swift` | `@Dependency` | Flag `hasCompletedOnboarding` en `UserDefaults` (preferencia de app, no dato de dominio) (RELEASE-001 F1). |

---

## Persistencia (SwiftData)

**Path:** `FuelMap/Core/Persistence/`

| File | Type | Responsibility |
|---|---|---|
| `FavoriteStation.swift` | `@Model` | Estación favorita persistida (id único, nombre, coords, addedAt) (FM-12). |
| `FavoritesClient.swift` | `@Dependency` + `@ModelActor` | `FavoritesStore` (actor, ModelContext) + `FavoritesClient` (isFavorite/toggle/all); `ModelContainer.fuelMapShared` (FM-12). |

> No se usa `.modelContainer` en la vista (no hay `@Query`); el acceso va por `FavoritesClient`/`@ModelActor`.

## Backend (fuera del repo iOS)

**Path:** `backend/` (FM-2/FM-3, código hecho; despliegue cloud pendiente)

| File | Responsibility |
|---|---|
| `backend/migrations/0001_init.sql` | Esquema (`stations`,`prices`,`sync_runs`) + PostGIS + índices GIST + RPC `nearby_stations` + RLS read-only (anon) + grants (FM-2). |
| `backend/migrations/0002_station_detail.sql` | RPC `station_detail(in_id)` — todos los combustibles de una estación (FM-5). |
| `backend/migrations/0003_expose_fuel_raw.sql` | Añade `fuel_raw` (nombre MIMIT original) a las RPC; drop+recreate por cambio de tipo de retorno. |
| `backend/migrations/0004_stations_by_ids.sql` | RPC `stations_by_ids(in_ids, in_fuel, in_self_only)` — precios de un lote de estaciones (favoritos), filtrado en servidor; mismo shape que `nearby_stations`, `distance_m = 0` (FAV-PRICE). |
| `backend/sync/parse.mjs` | Parse CSV pipe-separated; salta `Estrazione`+cabecera; valida coords (NF6); dtComu (FM-3). |
| `backend/sync/fuel-mapping.mjs` | `normalizeFuel` descCarburante→FuelType (ADR-003) (FM-3). |
| `backend/sync/sync.mjs` | Descarga MIMIT → upsert stations + reemplazo prices + `sync_runs` (service_role) (FM-3). |
| `backend/sync/sync.test.mjs` | Tests del parser/mapeo (`node --test`) (FM-3). |
| `.github/workflows/sync-mimit.yml` | Cron 06:30 UTC + `workflow_dispatch` (FM-3). |
| `backend/README.md` | Runbook de despliegue (Supabase + secrets + push). |

---

## Module Boundaries & Rules

- Features dependen de Core vía `@Dependency` — nunca al revés.
- DTOs viven en `Core/Network/DTOs` y se mapean a Models de dominio en el límite del APIClient.
- Los Models de dominio no conocen Supabase ni DTOs.
- Diseño de modelos/queries agnóstico al país (escalabilidad fuera de Italia).

---

> ## Usage rules
>
> - **Update on every architectural change.** Sustituir `<!-- VERIFY -->` por la responsabilidad real al implementar.
> - **One-line responsibility per row.**
> - **Reference ADRs** en la columna de responsabilidad cuando un archivo encarna una decisión.
> - **Don't catalog test files** here (van en PHASE_LOG, por QA).
