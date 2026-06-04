# System Map — FuelMap

> Module map and key file reference. Agents read from here to navigate the codebase without loading the entire repo.
> Last updated: 2026-06-04 (FM-1 completado)

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
| `App/AppFeature.swift` | Reducer | Raíz; `Scope` a `MapFeature` (FM-7). |
| `App/AppView.swift` | View | Raíz; aloja `MapView` (FM-7). |
| `Map/MapFeature.swift` | Reducer | State del mapa; permisos→ubicación, carga con debounce/cancelación, guard de jitter, `@Presents detail`, error (FM-7/FM-9). |
| `Map/MapView.swift` | View | `Map` iOS 17+, annotations de precio, `onMapCameraChange`, recentrado, status bar (FM-7). |
| `Map/StationPin.swift` | View | Pin de precio (cápsula + puntero); `isCheapest` para FM-10 (FM-7). |
| `Filters/FiltersFeature.swift` | Reducer | `BindingReducer`; estado `fuel`/`selfOnly`/`radiusKm` (movido desde MapFeature). `RadiusOption` (FM-8). |
| `Filters/FiltersView.swift` | View | Segmented combustible + toggle self + menú radio; panel inferior del mapa (FM-8). |
| `StationDetail/StationDetailFeature.swift` | Reducer | Carga detalle completo (`stationDetail`); deep link Apple Maps (`openURL`); `dismiss` (FM-9). |
| `StationDetail/StationDetailView.swift` | View | Sheet: precios por combustible (self/servito) + hora + "Indicazioni" (FM-9). |

---

## Core Layer

**Path:** `FuelMap/Core/` *(a crear)*

| File | Type | Responsibility |
|---|---|---|
| `Models/Station.swift` | struct | Modelo de dominio de impianto; `cheapest` deriva el precio mínimo (FM-4). |
| `Models/FuelPrice.swift` | struct | Precio por combustible: `fuel`, `price` (Decimal 3 dec.), `isSelf`, `communicatedAt` (FM-4). |
| `Models/FuelType.swift` | enum | benzina/gasolio/gpl/metano/hvo/altro; rawValue = normalización backend (ADR-003, FM-4). |
| `Models/Coordinate.swift` | struct | Coordenada validada; `validated(lat:lng:)` descarta nulas/(0,0)/fuera de rango (NF6, FM-4). |
| `Network/DTOs/NearbyStationRowDTO.swift` | Decodable | Fila plana de la RPC `nearby_stations` (RFC §3.1, FM-4). |
| `Network/DTOs/StationMapper.swift` | enum | Agrupa filas por estación → `[Station]`; descarta coords inválidas, normaliza fuel (FM-4). |
| `Network/DTOs/JSONDecoder+FuelMap.swift` | ext | Decoder compartido: convertFromSnakeCase + fechas ISO8601 (FM-4). |
| `Network/DTOs/ISO8601.swift` | enum | Parseo ISO8601 tolerante a fracciones de segundo (FM-4). |
| `Foundation/Decimal+Rounding.swift` | ext | `rounded(_:mode:)` para precios a 3 decimales (FM-4). |
| `Foundation/String+NilIfEmpty.swift` | ext | `nilIfEmpty` para campos vacíos del MIMIT (FM-4). |
| `Network/APIClient.swift` | `@Dependency` | `nearbyStations`/`stationDetail` async; `APIError` tipado. `liveValue` = mock TEMP hasta FM-2/FM-3 (ADR-001) (FM-5). |
| `Network/APIClient+Mock.swift` | mock + fixtures | `APIClient.mock()` filtra/ordena por precio; `StationFixtures` (6 estaciones de Roma) para mock y previews (FM-5). |
| `Location/LocationClient.swift` | `@Dependency` | Wrapper CoreLocation (coordinador `@MainActor` + `LockIsolated` para status síncrono); `authorizationStatus`/`requestWhenInUse`/`currentLocation`; `LocationError` (FM-6). |
| `Ads/AdClient.swift` | `@Dependency` | <!-- VERIFY --> Integración AdMob banner (FM-11) |

---

## Backend (fuera del repo iOS)

| Componente | Responsibility |
|---|---|
| Supabase | PostgreSQL + PostGIS. Tablas `stations`, `prices`. RPC geoespacial `nearby_stations(lat,lng,radius_km,fuel)`. API REST autogenerada. |
| GitHub Actions (sync) | Cron diario: descarga `anagrafica_impianti_attivi.csv` + `prezzo_alle_8.csv` del MIMIT → upsert en Supabase. |

> El esquema SQL y el script de sync se definirán en el RFC. Ubicación del código de sync (mismo repo `/backend` o repo aparte) a decidir en RFC.

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
