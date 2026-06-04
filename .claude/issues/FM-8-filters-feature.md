# FM-8: FiltersFeature + FiltersView

> Derivado de RFC-001 §6.2. Self-contained.

## Description
Implementar los filtros: tipo de combustible, self-service/servito y radio de búsqueda. Al cambiar, MapFeature recarga las estaciones.

Complexity: M
Dependencies: FM-7

## Files to Modify
- `Features/Filters/FiltersFeature.swift` (nuevo) — reducer.
- `Features/Filters/FiltersView.swift` (nuevo) — UI (picker combustible, toggle self, slider/segmented radio).
- `Features/Map/MapFeature.swift` — integrar filtros (scope/binding) y disparar recarga al cambiar.

## Technical Specification (from RFC)
**Source:** RFC §6.2 (FiltersFeature).

- `FuelType` picker (CaseIterable, excluyendo `altro` del selector salvo que haya datos).
- Toggle `selfOnly`.
- `radiusKm` ∈ {1, 3, 5, 10, 20} (segmented) o slider.
- Cambios fluyen a `MapFeature.State` (binding) y disparan `reload` (que respeta el debounce/cancelación de FM-7).

## What NOT to Do
- Do NOT hacer la llamada de red desde FiltersFeature (la hace MapFeature).
- Do NOT persistir filtros aún (posible mejora futura; v1 en memoria).

## Tests to Add
```swift
@Test func filters_changingFuel_triggersMapReload()
@Test func filters_toggleSelfOnly_updatesState()
@Test func filters_changingRadius_triggersReload()
```

Mock/stub strategy: `TestStore` componiendo Filters dentro de Map; assert de efecto `reload`.

## Status: DONE (2026-06-04)

> `fuel`/`selfOnly`/`radiusKm` movidos a `FiltersFeature.State` (estaban inline en MapFeature). `MapFeature` compone con `Scope` y recarga ante `.filters`. Fixtures enriquecidas con GPL/metano para demo. Tap headless no probado (sin idb); comportamiento cubierto por tests.

## Acceptance Criteria
- [x] Cambiar combustible/self/radio actualiza el estado y recarga el mapa (`map_filterChange_reloads`).
- [x] UI con material; Dynamic Type a fondo en FM-13.
- [x] `#Preview` para `FiltersView`.
- [x] Tests pass: 4 nuevos (FiltersFeatureTests×3 + map_filterChange_reloads); 26 totales. SwiftLint 0.

## References
- RFC: §6.2
