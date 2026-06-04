# RFC: FuelMap — Arquitectura técnica (iOS + Supabase + sync MIMIT)

> Request for Comments. Technical design document.
> Every section is numbered — GitHub issues reference these sections for traceability.
> Must be aligned with the PRD and project vision.

## Status
Accepted

## Date
2026-06-04

## PRD Reference
`.claude/prd/PRD-001-fuelmap.md` (Approved, 2026-06-04)

## Summary
Construimos una app iOS nativa (SwiftUI + MapKit, TCA, iOS 17+) que muestra gasolineras italianas y precios sobre un mapa, consumiendo una API geoespacial servida por Supabase (PostgreSQL + PostGIS). Los datos oficiales del MIMIT se ingieren a diario mediante un job de GitHub Actions que descarga los CSV, los normaliza y hace upsert en Supabase. Monetización con AdMob (banner) bajo consentimiento ATT + GDPR (UMP).

## Context & Motivation
No existe backend hoy (greenfield). Los datos oficiales del MIMIT son CSV diarios pesados (~22k impianti + cientos de miles de precios) con separador `|` (desde 2026-02-10) y `descCarburante` en texto libre con múltiples variantes. Parsear estos CSV en cliente y resolver "estaciones en radio de N km" sin índice geoespacial es inviable en el dispositivo. Por eso se introduce una capa de datos servida (Supabase) que ofrece consulta geoespacial indexada y JSON ligero al cliente, sin operar un servidor propio. Motivación de producto: ver PRD (UX moderna y velocidad frente a competencia anticuada).

---

## §1 Architecture Overview

```
┌──────────────────────────────┐      ┌─────────────────────────────┐
│  GitHub Actions (cron diario) │      │        MIMIT Open Data        │
│  sync-mimit.yml ~08:30 CET    │◀─────│  anagrafica_impianti_attivi   │
│  download → parse(|) →         │ HTTP │  prezzo_alle_8                │
│  normalize → upsert            │      │  (CSV pipe-separated, IODL2)  │
└───────────────┬──────────────┘      └─────────────────────────────┘
                │ Supabase service_role key (secret)
                ▼
┌──────────────────────────────────────────────────────────────────┐
│  Supabase (PostgreSQL + PostGIS)                                    │
│   tablas: stations, prices, sync_runs                               │
│   RPC: nearby_stations(lat,lng,radius_km,fuel,self_only)            │
│   índices: GIST(location), btree(station_id, fuel)                  │
│   RLS: anon = SELECT/RPC read-only                                  │
└───────────────┬──────────────────────────────────────────────────┘
                │ HTTPS REST/RPC  (anon key, read-only)
                ▼
┌──────────────────────────────────────────────────────────────────┐
│  iOS App — TCA                                                      │
│   AppFeature (root Store)                                           │
│    ├── MapFeature ──── MapView (Map iOS17+, clustering, banner)     │
│    ├── FiltersFeature ─ FiltersView (fuel, self/servito, radio)     │
│    └── StationDetailFeature ─ StationDetailView                     │
│   @Dependency: APIClient (Supabase), LocationClient (CoreLocation), │
│                AdClient (AdMob+UMP), FavoritesClient (SwiftData)     │
└──────────────────────────────────────────────────────────────────┘
```

Capas iOS: `Features/` (reducers + vistas) → `Core/` (`@Dependency` clients, DTOs, Models). DTOs viven en `Core/Network/DTOs` y se mapean a Models de dominio en el límite del APIClient.

## §2 Data Model

### §2.1 Esquema Supabase (PostgreSQL + PostGIS)

```sql
-- Impianti (upsert desde anagrafica_impianti_attivi.csv)
create table stations (
  id          bigint primary key,            -- idImpianto
  manager     text,                          -- Gestore
  brand       text,                          -- Bandiera
  type        text,                          -- Tipo Impianto (Stradale/Autostradale)
  name        text,                          -- Nome Impianto
  address     text,                          -- Indirizzo
  municipality text,                         -- Comune
  province    text,                          -- Provincia (sigla)
  location    geography(Point, 4326),        -- desde Latitudine/Longitudine
  country     char(2) not null default 'IT', -- agnóstico al país (escalabilidad)
  updated_at  timestamptz not null default now()
);
create index stations_location_gix on stations using gist (location);
create index stations_province_idx on stations (province);

-- Precios (reemplazo diario desde prezzo_alle_8.csv)
create table prices (
  station_id  bigint not null references stations(id) on delete cascade,
  fuel        text   not null,   -- descCarburante normalizado (ver §6.3)
  fuel_raw    text   not null,   -- descCarburante original (auditoría)
  price       numeric(6,3) not null,
  is_self     boolean not null,  -- isSelf 1=self / 0=servito
  communicated_at timestamptz,   -- dtComu
  primary key (station_id, fuel_raw, is_self)
);
create index prices_lookup_idx on prices (fuel, is_self);
create index prices_station_idx on prices (station_id);

-- Telemetría del sync (observabilidad)
create table sync_runs (
  id          bigserial primary key,
  started_at  timestamptz not null default now(),
  finished_at timestamptz,
  stations_upserted int,
  prices_upserted int,
  extraction_date date,          -- "Estrazione del ..." de la anagrafica
  status      text,              -- ok | partial | error
  notes       text
);
```

### §2.2 Modelos de dominio (Swift)

```swift
enum FuelType: String, Sendable, CaseIterable {   // normalizado
    case benzina, gasolio, gpl, metano, hvo
}

struct Station: Identifiable, Equatable, Sendable {
    let id: Int
    let name: String
    let brand: String?
    let address: String?
    let municipality: String?
    let province: String?
    let coordinate: Coordinate          // lat/lng validados (no opcionales aquí)
    let prices: [FuelPrice]
    var cheapest: FuelPrice? { prices.min { $0.price < $1.price } }
}

struct FuelPrice: Equatable, Sendable {
    let fuel: FuelType
    let price: Decimal
    let isSelf: Bool
    let communicatedAt: Date?
}

struct Coordinate: Equatable, Sendable { let latitude: Double; let longitude: Double }
```

## §3 Interfaces & Contracts

### §3.1 RPC geoespacial (Supabase)

```sql
create or replace function nearby_stations(
  in_lat double precision,
  in_lng double precision,
  in_radius_km double precision,
  in_fuel text,
  in_self_only boolean default false,
  in_limit int default 200
) returns table (
  id bigint, name text, brand text, address text,
  municipality text, province text,
  latitude double precision, longitude double precision,
  fuel text, price numeric, is_self boolean,
  communicated_at timestamptz, distance_m double precision
)
language sql stable as $$
  select s.id, s.name, s.brand, s.address, s.municipality, s.province,
         st_y(s.location::geometry), st_x(s.location::geometry),
         p.fuel, p.price, p.is_self, p.communicated_at,
         st_distance(s.location, st_makepoint(in_lng, in_lat)::geography)
  from stations s
  join prices p on p.station_id = s.id
  where p.fuel = in_fuel
    and (not in_self_only or p.is_self = true)
    and st_dwithin(s.location, st_makepoint(in_lng, in_lat)::geography, in_radius_km * 1000)
  order by p.price asc
  limit in_limit;
$$;
```

### §3.2 APIClient (TCA @Dependency, iOS)

```swift
struct APIClient: Sendable {
    /// Estaciones con el combustible dado dentro de `radiusKm` del punto.
    var nearbyStations: @Sendable (_ center: Coordinate, _ radiusKm: Double,
                                   _ fuel: FuelType, _ selfOnly: Bool) async throws -> [Station]
    /// Detalle completo (todos los combustibles) de una estación.
    var stationDetail: @Sendable (_ id: Int) async throws -> Station
}

enum APIError: Error, Equatable, Sendable {
    case network(String), decoding, unauthorized, server(Int), noResults
}
```

DTOs `Decodable` (nunca `Codable`), `.convertFromSnakeCase`, mapeados a `Station`/`FuelPrice` en el cliente. Filas con lat/lng inválidas se descartan en el mapeo (NF6).

### §3.3 LocationClient / AdClient

```swift
struct LocationClient: Sendable {
    var authorizationStatus: @Sendable () -> CLAuthorizationStatus
    var requestWhenInUse: @Sendable () async -> CLAuthorizationStatus
    var currentLocation: @Sendable () async throws -> Coordinate
}

struct AdClient: Sendable {
    var requestConsent: @Sendable () async -> Void          // UMP (GDPR) + ATT
    var bannerAdUnitID: @Sendable () -> String
}
```

## §4 Implementation Plan

> Cada fila = un issue de GitHub. `FM-` prefijo. Issues enlazan a su §6.x.

| Order | ID | Description | Complexity | Dependencies |
|---|---|---|---|---|
| 1 | FM-1 | Proyecto Xcode + estructura SPM/TCA, target iOS 17, dependencias (swift-composable-architecture, supabase-swift, GoogleMobileAds/UMP) | M | None |
| 2 | FM-2 | Esquema Supabase (§2.1) + RPC `nearby_stations` (§3.1) + RLS read-only + extensión PostGIS | M | None |
| 3 | FM-3 | Job de sync GitHub Actions (§6.3): descarga CSV `\|`, parse, normalización `descCarburante`→FuelType, validación coords, upsert, `sync_runs` | L | FM-2 |
| 4 | FM-4 | Modelos de dominio + DTOs + mapeo (§2.2, §3.2) | S | FM-1 |
| 5 | FM-5 | APIClient sobre supabase-swift (§3.2) con APIError tipado | M | FM-1, FM-2, FM-4 |
| 6 | FM-6 | LocationClient (CoreLocation wrapper) + manejo de permisos denegado/restringido (§6.1) | M | FM-1 |
| 7 | FM-7 | MapFeature + MapView: Map iOS17+, pins con precio, clustering, carga por región/radio (§6.2) | L | FM-4, FM-5, FM-6 |
| 8 | FM-8 | FiltersFeature + FiltersView: tipo combustible, self/servito, radio (§6.2) | M | FM-7 |
| 9 | FM-9 | StationDetailFeature + StationDetailView: todos los combustibles, deep link Apple Maps (§6.2) | M | FM-7 |
| 10 | FM-10 | Estación más barata destacada + orden por precio/distancia | S | FM-7, FM-8 |
| 11 | FM-11 | AdClient: AdMob banner + UMP (GDPR) + ATT prompt en onboarding (§6.4) | M | FM-1, FM-7 |
| 12 | FM-12 | Favoritos en local (SwiftData) [Nice to have] | M | FM-9 |
| 13 | FM-13 | Accesibilidad (Dynamic Type, VoiceOver), estados loading/empty/error, localización it/es/en | M | FM-7, FM-8, FM-9 |
| 14 | FM-14 | Privacy nutrition labels, ATT/IODL2 atribución, prep TestFlight/App Store | S | FM-11, FM-13 |

## §5 Technical Decisions & Trade-offs

| Decision | Chosen | Alternative | Why |
|---|---|---|---|
| Capa de datos | Supabase (PostgreSQL+PostGIS) + GitHub Actions | BE propio Node/Fastify; API wrapper de terceros en Render; CSV en cliente | Coste ~0€, sin operar servidor, geo-query indexada. API wrapper free-tier = cold starts/sin SLA. CSV en cliente = inviable por tamaño. → **ADR-001** |
| Arquitectura iOS | TCA | MVVM, MV | Experiencia previa del equipo; state centralizado; testeo con TestStore; escala con features. → **ADR-002** |
| Mapa | `Map` SwiftUI iOS 17+ con `Annotation`/clustering | `MKMapView` (UIViewRepresentable) | API declarativa, menos código; suficiente para el caso. Reevaluar si clustering nativo se queda corto. |
| Normalización combustible | Tabla de mapeo `descCarburante`→`FuelType` en el sync, guardando `fuel_raw` | Mapear en cliente; mostrar texto crudo | Cliente recibe enum limpio; `fuel_raw` preserva auditoría ante nuevas variantes. → **ADR-003** |
| Sync trigger | GitHub Actions cron diario | Supabase Edge Function cron; cron en VPS | Gratis, versionado, logs; mantiene el proyecto free activo (evita pausa por inactividad). |
| Reemplazo de precios | Truncate+insert de `prices` por run (transaccional) | Upsert diff | Los precios cambian masivamente a diario; reemplazo total es más simple y consistente. |

> ADRs a crear: ADR-001 (capa de datos), ADR-002 (TCA), ADR-003 (normalización de combustible).

## §6 Detailed Design

### §6.1 Permisos de ubicación
LocationClient envuelve `CLLocationManager`. Estados: `notDetermined`→solicitar al primer onAppear; `denied/restricted`→MapFeature muestra estado con centrado por defecto (centro de Italia / última región) y CTA a Ajustes; `authorized`→centrar en usuario. Sin bloquear el main actor; manager en actor dedicado o `@MainActor` con continuations.

### §6.2 Features TCA
- **MapFeature**: `State{ region, fuel, selfOnly, radiusKm, stations, isLoading, selected, error }`. Acciones: `onAppear`, `locationUpdated`, `regionChanged(debounced)`, `stationsResponse(Result)`, `stationTapped`, `filtersChanged`. Efecto: `apiClient.nearbyStations` con cancelación al cambiar región/filtro (`.cancellable(id:)`). Debounce de `regionChanged` (~400 ms) para no saturar egress.
- **FiltersFeature**: binding de `FuelType`, `selfOnly`, `radiusKm`; al cambiar, MapFeature recarga.
- **StationDetailFeature**: carga `stationDetail(id)`; lista de combustibles self/servito; botón "Indicazioni" → `maps://?daddr=lat,lng`.

### §6.3 Job de sync (GitHub Actions)
`/.github/workflows/sync-mimit.yml` (cron `30 6 * * *` UTC ≈ 08:30 CEST). Script (Node o Python):
1. Descargar ambos CSV (HTTP GET, UTF-8/latin1 detect).
2. **anagrafica**: saltar 1ª línea `Estrazione del YYYY-MM-DD` (capturar la fecha → `sync_runs.extraction_date`); parsear con separador `|`; construir `location` desde Lat/Lng; **descartar filas sin coords válidas** o fuera de rango (NF6).
3. **prezzo**: parsear `|`; normalizar `descCarburante`→`FuelType` (tabla de mapeo, §5 ADR-003); guardar `fuel_raw`; loggear variantes no mapeadas en `sync_runs.notes`.
4. Upsert `stations` (on conflict id) + reemplazo transaccional de `prices`.
5. Registrar `sync_runs`. Fallar el workflow si status=error (alerta por email de GitHub).
Secrets: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` en GitHub Secrets. Ubicación del código de sync: **monorepo `/backend`** (decisión a confirmar en ADR-001).

### §6.4 AdMob + consentimiento
Onboarding: 1) Google UMP `requestConsentInfoUpdate` + form (GDPR, obligatorio UE/Italia); 2) tras UMP, ATT `requestTrackingAuthorization`. Banner adaptativo anclado en `VStack` **debajo** del mapa (nunca solapando). `NSUserTrackingUsageDescription`, `GADApplicationIdentifier`, `SKAdNetworkItems` en Info.plist. Ads no personalizados como fallback si el usuario rechaza.

## §7 Testing Strategy

| Area | Approach | Framework |
|---|---|---|
| Reducers (Map/Filters/Detail) | TestStore: acciones→estado, efectos con dependencies mockeadas | TCA TestStore + Swift Testing |
| APIClient mapping | DTO→Model, descarte de coords inválidas, APIError mapping | Swift Testing |
| LocationClient | Estados de autorización (mock manager) | Swift Testing |
| Sync script | Parse de fixtures CSV (pipe, línea Estrazione, variantes fuel), normalización, descarte coords | Vitest/pytest (en `/backend`) |
| RPC geoespacial | `nearby_stations` contra DB de prueba con datos seed | pgTAP / script SQL |
| UI smoke | Flujo abrir→mapa→detalle | XCUITest (mínimo) |

## §8 Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|
| MIMIT cambia formato/separador de nuevo | High | Med | Parser tolerante + `fuel_raw` + alerta en `sync_runs`; tests de parse con fixtures |
| Coords faltantes/erróneas en anagrafica | Med | High | Validación y descarte en sync (NF6); contador en `sync_runs` |
| Egress Supabase free (5 GB/mes) a escala | Med | Med | JSON ligero, `limit`, debounce de región; upgrade Pro $25 si se supera |
| Proyecto Supabase free pausado por inactividad | High | Low | Sync diario escribe → mantiene activo |
| Rechazo App Store por ATT/GDPR mal implementado | High | Med | UMP + ATT correctos (§6.4), privacy labels (FM-14) |
| `descCarburante` con variantes nuevas no mapeadas | Med | Med | Log de no-mapeadas; fallback a categoría "altro" sin romper el sync |
| MapKit clustering insuficiente con miles de pins | Med | Med | `limit` por radio; reevaluar MKMapView si hace falta |

## §9 What's NOT in Scope
- Países distintos de Italia (modelos ya agnósticos vía `country`, pero sin datos de otros países). — PRD non-goal
- Backend propio de servidor. — PRD non-goal
- Routing turn-by-turn (solo deep link a Apple Maps). — PRD non-goal
- Crowdsourcing de precios, login/cuentas, IAP/suscripciones. — PRD non-goals
- Sync >1×/día (revisión futura, no v1).

## §10 Rollout & Migration
1. FM-2/FM-3 primero: poblar Supabase y verificar un ciclo de sync completo antes de tocar la app.
2. App contra datos reales en TestFlight (beta interna) → beta externa.
3. Sin migración de datos (greenfield). Versionar esquema SQL en `/backend/migrations`.
4. App Store submission tras FM-14 (privacy labels, atribución IODL 2.0 en "Acerca de").

## References
- PRD: `.claude/prd/PRD-001-fuelmap.md`
- Related ADRs: ADR-001 (capa de datos), ADR-002 (TCA), ADR-003 (normalización combustible) — a crear.
- MIMIT Open Data: https://www.mimit.gov.it/it/open-data/elenco-dataset/carburanti-prezzi-praticati-e-anagrafica-degli-impianti
- CSV (verificados 2026-06-04): `/images/exportCSV/anagrafica_impianti_attivi.csv`, `/images/exportCSV/prezzo_alle_8.csv` (separador `|` desde 2026-02-10, IODL 2.0)
- Supabase free tier: https://supabase.com/pricing
- AdMob ATT/UMP: https://developers.google.com/admob/ios/privacy/idfa

---

> **Workflow:** §4 → backlog de issues. Cada issue enlaza a su §6.x. Cambios a un RFC Accepted requieren nueva sección o RFC que lo supersede.
