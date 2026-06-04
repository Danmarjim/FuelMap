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

## Acceptance Criteria
- [ ] Cambiar combustible/self/radio actualiza el estado y recarga el mapa.
- [ ] UI accesible (Dynamic Type; detalle a fondo en FM-13).
- [ ] `#Preview` para `FiltersView`.
- [ ] Tests pass.

## References
- RFC: §6.2
