# FM-10: Estación más barata destacada + orden por precio/distancia

> Derivado de RFC-001 §4 (F7, F13 del PRD). Self-contained.

## Description
Destacar visualmente la estación más barata del radio actual y permitir ordenar la lista de estaciones por precio o por distancia.

Complexity: S
Dependencies: FM-7, FM-8

## Files to Modify
- `Features/Map/MapFeature.swift` — derivar la estación más barata del set actual; estado `sortOrder`.
- `Features/Map/MapView.swift` / `StationPin.swift` — estilo destacado para la más barata.
- (Si hay lista) `Features/Map/StationListView.swift` (nuevo, opcional) — orden por precio/distancia.

## Technical Specification (from RFC)
**Source:** RFC §4 (FM-10); PRD F7, F13.

- Más barata = `min` por `price` del combustible seleccionado dentro del set cargado.
- `sortOrder ∈ {price, distance}`; distancia desde el centro/usuario (la RPC ya devuelve `distance_m`).
- El pin más barato usa un estilo distintivo (color/tamaño/badge).

## What NOT to Do
- Do NOT recalcular llamando a la red (deriva del estado ya cargado).
- Do NOT añadir una pantalla de lista compleja si no aporta (mínimo viable).

## Tests to Add
```swift
@Test func map_derivesCheapestStation()
@Test func map_sortByDistance_ordersAscending()
@Test func map_sortByPrice_ordersAscending()
```

Mock/stub strategy: `TestStore` con set de estaciones fixture.

## Acceptance Criteria
- [ ] La estación más barata del radio se distingue visualmente.
- [ ] Orden por precio y por distancia funciona.
- [ ] Tests pass.

## References
- RFC: §4; PRD F7, F13
