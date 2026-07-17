# System Map — FuelMap

> Module map and key file reference. Agents read from here to navigate the codebase without loading the entire repo.
> Last updated: 2026-06-08 (RESTYLE-001 — design system aplicado R0–R6)

## Design System layer

**Path:** `FuelMap/DesignSystem/` + `FuelMap/Assets.xcassets/Colors/` (tokens) · fuente de verdad en `.claude/design/`.

| File | Type | Responsibility |
|---|---|---|
| `Assets.xcassets/Colors/*.colorset` | tokens | 35 Color sets semánticos claro/oscuro (brand, surfaces, text, lines, price tiers, functional, `goldInk`). Tiers *fill* = valor único (mode-independent). `Color(.brandPrimary)`. |
| `DesignSystem/Spacing.swift` | enum | Escala 4pt (`s1`…`s10`). |
| `DesignSystem/Radius.swift` | enum | Radios sm/md/lg/xl/pill. |
| `DesignSystem/Elevation.swift` | modifier | `.elevation(.e1/.e2/.e3/.pin/.pinSelected/.sheet)`; profundiza en oscuro. |
| `DesignSystem/Typography.swift` | ext Font | Roles SF Pro mapeados a text styles (Dynamic Type) + fuentes de precio tabulares. |
| `DesignSystem/TokenGallery.swift` | View (#Preview) | Galería de validación de la paleta claro/oscuro. |
| `Features/Map/SheetComponents.swift` | Views | `TierTag`, `BestFlag`, `SortPill`, `SheetHeader`, `SheetEmptyState`, `FreshnessPill`, `StationRow` (con `unavailableNote` para filas sin precio), `SkeletonRow/List` + `shimmer()`. |

> **En construcción.** Esqueleto TCA en marcha (FM-1). Las tablas marcadas `<!-- VERIFY -->` se rellenan conforme se implementan sus issues.

## Tooling del proyecto

| Archivo | Responsibility |
|---|---|
| `project.yml` | Spec XcodeGen: target iOS 17, Swift 6 strict concurrency, paquete SPM TCA. Genera `FuelMap.xcodeproj` (no commiteado). |
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
| `Map/MapFeature.swift` | Reducer | State del mapa; permisos→ubicación, carga con debounce/cancelación, guard de jitter, `@Presents detail`, error, `mapStyle` (capas, R2). Precios en vivo de favoritos: `favoriteStations` + efecto cancelable, refresco al cambiar filtro; derivados `favoriteDisplays`/`cheapestFavoriteID`/`favoritePriceTiers` (FAV-PRICE). `MapStyleOption`/`StationSort`/`FavoriteDisplay`/`MapDefaults`. |
| `Map/MapView.swift` | View | `Map` iOS 17+, annotations de precio, `onMapCameraChange`, recentrado (Reduce Motion), `.mapStyle`, status banner flotante + float controls (lista/favoritos/capas) (R2). |
| `Map/MapClustering.swift` | lógica | `MapItem`/`StationCluster` + grid clustering por zoom (ADR-004, FM-15). |
| `Map/ClusterPin.swift` | View | Cluster: burbuja `surfaceElevated` + cápsula `da X` con tier de la más barata (R2). |
| `Map/PriceTiers.swift` | lógica | Terciles → `PriceTier` con `fill`/`ink`/`surface` + `symbolName` (▲●▼) + `label` localizada (daltónico-seguro, R1). |
| `Map/BrandStyle.swift` | lógica | Normaliza `Bandiera`→marca (color+monograma+asset+`logoBackground`) (FM-16). |
| `Map/BrandBadge.swift` | View | Chip de marca: logo sobre `logoBackground` o monograma/pompa neutro (R2). |
| `Map/StationPin.swift` | View | Pin: cápsula de tier + badge + forma de tier + precio + cola + halo; seleccionado/más barata; Reduce Motion + Dynamic Type capada (R2/R5). |
| `Map/StationListView.swift` | View | Hoja: header + sort pills + `StationRow` (chip, best-flag, precio, tier-tag); skeleton de carga; estado vacío (R4/R5). |
| `Map/FavoritesView.swift` | View | Hoja de favoritos con precio en vivo: orden por precio, `BestFlag` en el más barato, distancia + `TierTag`, "n/d" si no vende el combustible activo; skeleton en la 1ª carga; estado vacío (R4/FAV-PRICE). |
| `Filters/FiltersFeature.swift` | Reducer | `BindingReducer`; estado `fuel`/`selfOnly`/`radiusKm`. `RadiusOption` (FM-8). |
| `Filters/FiltersView.swift` | View | Barra: segmentado combustible + toggle Self + stepper radio + sort pills; fondo degradado (R3). |
| `StationDetail/StationDetailFeature.swift` | Reducer | Carga detalle completo (`stationDetail`); deep link Apple Maps (`openURL`); `dismiss` (FM-9). |
| `StationDetail/StationDetailView.swift` | View | Hoja: hero + precios por variante (Self/Servito, filtrado destacado), `FreshnessPill`, CTA Indicazioni→selector de navegación (R4). |
| `StationDetail/NavApp.swift` | enum | Apple/Google/Waze: deep links de indicaciones + probe de instalación (FM-17). |

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
| `Ads/AdClient.swift` | `@Dependency` | <!-- VERIFY --> Integración AdMob banner (FM-11) |

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
