# FuelMap

App iOS nativa que muestra gasolineras italianas y sus precios de carburante sobre un mapa, usando los datos abiertos oficiales del MIMIT. Gratis con ads. Italia primero, escalable a otros países.

> **Module map and file lookup → `.claude/SYSTEM_MAP.md`.**
> **History and phase log → `.claude/PHASE_LOG.md`.**
> **Decisions → `.claude/decisions/ADR-*.md`.**
> **Active work → `.claude/plan.md`.**
> **Product → `.claude/prd/`. Technical design → `.claude/rfc/`.**

## Tech stack

| | |
|---|---|
| UI | SwiftUI (100% declarative) + MapKit (`Map` iOS 17+) |
| Concurrency | Swift 6, strict concurrency (`-strict-concurrency=complete`) |
| Architecture | TCA (The Composable Architecture) |
| Location | CoreLocation (wrapped as TCA `@Dependency`) |
| Persistence | TBD en RFC (SwiftData para favoritos/cache local; sin servidor propio) |
| Backend datos | Supabase (PostgreSQL + PostGIS), API REST/RPC geoespacial autogenerada |
| Data sync | GitHub Actions: descarga diaria CSV MIMIT → upsert Supabase |
| Networking | URLSession async/await; API clients como protocolos / `@Dependency` |
| Ads | Google AdMob (banner inferior, fuera del área del mapa) |
| Build | XcodeGen (`project.yml` → `.xcodeproj` generado, no commiteado) |
| Min target | iOS 17+ |

## Build & test

El `.xcodeproj` se **genera** desde `project.yml` (no se commitea). Xcode 26.5 está en `/Applications/Xcode_26.5.app` pero `xcode-select` apunta a CommandLineTools; los builds usan `DEVELOPER_DIR` (sin `sudo`). Las macros de TCA requieren `-skipMacroValidation` en builds headless.

```bash
export DEVELOPER_DIR=/Applications/Xcode_26.5.app/Contents/Developer

# (Re)generar el proyecto tras tocar project.yml o añadir archivos
xcodegen generate

# Build
xcodebuild -project FuelMap.xcodeproj -scheme FuelMap \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -skipMacroValidation -skipPackagePluginValidation build

# Tests (Swift Testing)
xcodebuild -project FuelMap.xcodeproj -scheme FuelMap \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -skipMacroValidation -skipPackagePluginValidation test

# Lint (necesita DEVELOPER_DIR para sourcekit)
swiftlint lint --quiet FuelMap FuelMapTests
```

> Quirk: el test target depende SOLO del host app (no re-enlaza el paquete TCA), si no aparecen *undefined symbols* de `CasePathsCore`/`PerceptionCore`.

## Architecture

TCA. Cada feature (`Map`, `StationDetail`, `Filters`) es un `Reducer` con `State`/`Action`/`body`, dependencias inyectadas vía `@Dependency` (APIClient, LocationClient) para testeo con `TestStore`. Detalle en `.claude/SYSTEM_MAP.md`.

## State management

```
Dependencies (@Dependency: APIClient, LocationClient, AdClient)
    ↓
Reducers (MapFeature, StationDetailFeature, FiltersFeature)
    ↓ (Store / @Bindable)
SwiftUI Views (MapView, StationDetailView, FiltersView)
```

Pattern: TCA. Vistas observan el `Store`; las acciones fluyen al reducer; los efectos llaman a las dependencies.

## Critical constraints (settled — don't propose alternatives)

1. Sin backend propio: los datos vienen de Supabase, alimentado por sync de GitHub Actions desde los CSV del MIMIT.
2. Fuente de datos oficial: MIMIT Open Data (licencia IODL 2.0), actualización diaria a las ~08:00.
3. Arquitectura TCA — no proponer MVVM/MV.
4. iOS 17+ mínimo; Swift 6 strict concurrency completa.
5. SwiftUI + MapKit nativo. Sin UIKit salvo wrappers imprescindibles (p. ej. AdMob banner via `UIViewRepresentable`).
6. Mercado inicial Italia; diseñar modelos y queries geo de forma agnóstica al país para escalar.

## Quirks to remember

- Las coordenadas del MIMIT son "voluntarias": algunos impianti pueden carecer de lat/lng → filtrar/validar al ingerir.
- Precios con 3 decimales (`NUMERIC(5,3)`); distinguir `isSelf` (self-service vs servito).
- Render free tier de la API wrapper de terceros = cold starts → descartado a favor de Supabase propio.
- AdMob banner debe ir FUERA del área del mapa para no degradar la UX del mapa.

## Conventions

### File headers
```swift
//
//  FileName.swift
//  FuelMap
//
//  Created on DD/MM/YYYY.
//
```

### Section markers
```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Public Methods
// MARK: - Private Helpers
```

### Data & networking (global standards)
- DTOs de respuesta `Decodable`, bodies `Encodable`. **Nunca `Codable`.**
- `CodingKeys` solo si difieren nombres; preferir `.convertFromSnakeCase`.
- Errores tipados (enums). Nunca `Error` crudo.

### Error handling
Definir enum de error de dominio (p. ej. `FuelMapError`) en RFC; mapear errores de red/Supabase en el límite del APIClient.

## Localization

Idiomas: italiano (primario), español, inglés. Strings en catálogo de strings (`.xcstrings`).

## Workflow notes

- **Decisions** → `.claude/decisions/ADR-XXX-*.md` (numbered, frozen).
- **History** → `.claude/PHASE_LOG.md` (architect / developer / qa / review per phase).
- **Active work** → `.claude/plan.md`. Closed plans → `.claude/plan-archive/`.
- **Code map** → `.claude/SYSTEM_MAP.md`. Update on phase close.
- New significant work → invoke `ios-team-lead` first.
