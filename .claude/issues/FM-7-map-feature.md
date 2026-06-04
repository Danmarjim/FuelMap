# FM-7: MapFeature + MapView (mapa con pins de precio y clustering)

> Derivado de RFC-001 §6.2, §1. Self-contained.

## Description
Implementar la feature principal: mapa SwiftUI (iOS 17+) centrado en el usuario, con pins de gasolineras mostrando el precio del combustible seleccionado, clustering, y carga de estaciones por región/radio con debounce y cancelación.

Complexity: L
Dependencies: FM-4, FM-5, FM-6

## Files to Modify
- `Features/Map/MapFeature.swift` (nuevo) — reducer.
- `Features/Map/MapView.swift` (nuevo) — `Map` + annotations + clustering.
- `Features/Map/StationPin.swift` (nuevo) — pin con precio.
- `App/AppFeature.swift` — componer `MapFeature`.

## Technical Specification (from RFC)
**Source:** RFC §6.2 (MapFeature), §1.

```swift
@Reducer struct MapFeature {
  @ObservableState struct State: Equatable {
    var region: MKCoordinateRegion
    var fuel: FuelType = .benzina
    var selfOnly = false
    var radiusKm: Double = 5
    var stations: [Station] = []
    var isLoading = false
    var selected: Station?
    var error: String?
  }
  enum Action { case onAppear, locationUpdated(Coordinate), regionChanged(MKCoordinateRegion),
                     stationsResponse(Result<[Station], APIError>), stationTapped(Station), reload }
}
```

- `onAppear` → pedir ubicación (LocationClient) y cargar.
- `regionChanged` **debounced ~400 ms** → `apiClient.nearbyStations`, efecto `.cancellable(id:)` (cancela la carga anterior).
- `Map` iOS 17+ con `Annotation` + `clusteringIdentifier`; `UserAnnotation()`.
- Estados loading/empty/error explícitos (detalle de a11y en FM-13).

## What NOT to Do
- Do NOT implementar filtros UI aquí (es FM-8, solo el estado `fuel/selfOnly/radiusKm`).
- Do NOT implementar el detalle (es FM-9; aquí solo `stationTapped` setea `selected`).
- Do NOT integrar AdMob aquí (es FM-11; dejar el hueco en el layout).
- Do NOT usar `MKMapView` salvo que el clustering nativo de `Map` resulte insuficiente (documentar si ocurre).

## Tests to Add
```swift
@Test func map_onAppear_loadsStationsAtUserLocation()
@Test func map_regionChanged_debouncesAndCancelsPrevious()
@Test func map_stationsResponseFailure_setsError()
@Test func map_stationTapped_setsSelected()
```

Mock/stub strategy: `TestStore` con `apiClient`/`locationClient` `testValue`; reloj de test para el debounce.

## Status: DONE (2026-06-04) — clustering diferido a deuda

> Verificado en simulador (iPhone 17, iOS 26.5): pins de precio sobre Roma, recentrado y debounce OK. Bug corregido: jitter de cámara dejaba `isLoading` pegado → guard de epsilon. `selected` se almacena (presentación del detalle en FM-9).

## Acceptance Criteria
- [x] El mapa se centra en el usuario (o región por defecto si denegado) y muestra pins con precio.
- [x] Cambiar región recarga con debounce (400 ms) y cancela la petición anterior (`.cancellable(cancelInFlight:)`).
- [~] **Clustering → DEUDA.** SwiftUI `Map` iOS 17 no clusteriza annotations custom; con datos reales (~22k) hará falta `MKMapView`/grid. No necesario con el mock (6). Registrado en plan.md.
- [x] Estados loading/empty/error manejados (status bar).
- [x] Tests pass: 6 nuevos (`MapFeatureTests`); 22 totales. SwiftLint 0.

## References
- RFC: §6.2, §1
- ADR-002 (TCA)
