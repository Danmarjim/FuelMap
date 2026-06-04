# FM-9: StationDetailFeature + StationDetailView

> Derivado de RFC-001 §6.2. Self-contained.

## Description
Implementar el detalle de estación: nombre, bandera, dirección, todos los combustibles con precio self/servito y hora de actualización, y deep link a Apple Maps para "cómo llegar".

Complexity: M
Dependencies: FM-7

## Files to Modify
- `Features/StationDetail/StationDetailFeature.swift` (nuevo) — reducer.
- `Features/StationDetail/StationDetailView.swift` (nuevo) — UI (sheet o push).
- `Features/Map/MapFeature.swift` — presentar el detalle desde `selected` (`@Presents`).

## Technical Specification (from RFC)
**Source:** RFC §6.2 (StationDetailFeature).

- `onAppear` → `apiClient.stationDetail(id)` (todos los combustibles).
- Lista de `FuelPrice` agrupada por combustible, distinguiendo self/servito; mostrar `communicatedAt`.
- Botón "Indicazioni" → abrir `maps://?daddr=<lat>,<lng>` (o `http://maps.apple.com/?daddr=`).
- Presentación desde MapFeature vía `@Presents` / `ifLet`.

## What NOT to Do
- Do NOT implementar favoritos aquí (es FM-12).
- Do NOT implementar routing propio (solo deep link a Apple Maps).
- Do NOT recargar el mapa al cerrar el detalle.

## Tests to Add
```swift
@Test func detail_onAppear_loadsFullStation()
@Test func detail_directions_buildsAppleMapsURL()
@Test func detail_loadFailure_showsError()
```

Mock/stub strategy: `TestStore` con `apiClient.stationDetail` `testValue`.

## Acceptance Criteria
- [ ] El detalle muestra todos los combustibles con self/servito y hora.
- [ ] "Indicazioni" abre Apple Maps con destino correcto.
- [ ] Estados loading/error manejados.
- [ ] `#Preview` para `StationDetailView`.
- [ ] Tests pass.

## References
- RFC: §6.2
