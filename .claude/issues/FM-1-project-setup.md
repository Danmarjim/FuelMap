# FM-1: Proyecto Xcode + estructura TCA + dependencias

> Derivado de RFC-001 §1, §4. Self-contained.

## Description
Crear el proyecto Xcode de FuelMap (iOS 17+, Swift 6 strict concurrency) con la estructura de carpetas TCA (`App/`, `Features/`, `Core/`) y las dependencias base. Base sobre la que se construye todo lo demás.

Complexity: M
Dependencies: None

## Files to Modify
- `FuelMap.xcodeproj` (nuevo) — target iOS 17, Swift 6, `-strict-concurrency=complete`.
- `Package.swift` o SPM deps en el proyecto — añadir paquetes.
- `App/FuelMapApp.swift` (nuevo) — `@main`, root `Store` con `AppFeature`.
- `App/AppFeature.swift` (nuevo) — reducer raíz que compondrá Map/Filters/Detail.
- Estructura de carpetas: `Features/Map`, `Features/Filters`, `Features/StationDetail`, `Core/Network`, `Core/Network/DTOs`, `Core/Location`, `Core/Ads`, `Core/Models`.

## Technical Specification (from RFC)
**Source:** RFC §1 (capas iOS), §5 (decisiones).

Dependencias (SPM):
- `swift-composable-architecture` (Point-Free) — TCA.
- `supabase-swift` — cliente Supabase (usado en FM-5).
- `GoogleMobileAds` + UMP — AdMob (usado en FM-11).

Configuración:
- Min deployment iOS 17.0.
- Swift 6, strict concurrency completa.
- Bundle id placeholder `com.danmarjim.fuelmap` (ajustable).

## What NOT to Do
- Do NOT implementar features ni clients todavía (solo esqueletos vacíos de `AppFeature`).
- Do NOT integrar AdMob ni Supabase en código aún (solo declarar las dependencias).
- Do NOT crear el backend (es FM-2/FM-3).

## Tests to Add
- `AppFeatureTests` mínimo: el `TestStore` de `AppFeature` se inicializa sin acciones pendientes.

```swift
@Test func appFeature_initialState() async {
    let store = await TestStore(initialState: AppFeature.State()) { AppFeature() }
    // sin efectos pendientes en init
}
```

Mock/stub strategy: dependencias por defecto de TCA (`withDependencies`).

## Status: DONE (2026-06-04)

> **Ajuste de scope:** en FM-1 se añade solo el paquete SPM **TCA**. `supabase-swift` y `GoogleMobileAds/UMP` se incorporan en FM-5 y FM-11 respectivamente (build inicial ligero + estrategia de mocks pedida por el usuario). Generación del proyecto vía **XcodeGen** (`project.yml`).

## Acceptance Criteria
- [x] El proyecto compila para iOS 17 Simulator (ejecutado en iPhone 17 / iOS 26.5) con Swift 6 strict concurrency `complete`, sin warnings de concurrencia.
- [x] Estructura `App/` creada; `Core/`/`Features/` se crean en sus issues.
- [x] Dependencia SPM TCA resuelta (supabase-swift/AdMob diferidos a FM-5/FM-11 — ver ajuste de scope).
- [x] `FuelMapApp` lanza placeholder (`ContentUnavailableView`) con el `Store` raíz.
- [x] Tests pass: 1 test Swift Testing (`AppFeatureTests`) passing. SwiftLint 0 violations.

## References
- RFC: `.claude/rfc/RFC-001-fuelmap-architecture.md` §1, §4, §5
- ADR-002 (TCA)
