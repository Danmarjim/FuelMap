# ADR-002: Arquitectura iOS con TCA (The Composable Architecture)

> Fecha: 2026-06-04
> Estado: Aceptado
> Contexto: RFC-001 §5. Decisión fundacional del patrón de arquitectura de la app iOS.

---

## 1. Contexto

FuelMap tiene complejidad de estado moderada-alta: un mapa que reacciona a ubicación, región, filtros (combustible, self/servito, radio) y selección, más detalle de estación y onboarding de consentimiento. Necesitamos estado predecible, efectos cancelables (recargas al cambiar región/filtro) y testeo exhaustivo de la lógica. El equipo ya tiene experiencia con TCA (PhotoSi).

---

## 2. Decisión

Adoptar **TCA** como patrón único de la capa de presentación.

### 2.1 Features como Reducers

Cada feature es un `Reducer` con `State`/`Action`/`body`: `AppFeature` (root), `MapFeature`, `FiltersFeature`, `StationDetailFeature` (RFC §6.2). Las vistas observan el `Store`.

```swift
@Reducer struct MapFeature {
    @ObservableState struct State: Equatable { /* region, fuel, selfOnly, radiusKm, stations, isLoading, selected, error */ }
    enum Action { case onAppear, regionChanged(MKCoordinateRegion), stationsResponse(Result<[Station], APIError>), /* ... */ }
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.locationClient) var locationClient
}
```

Justificación:
- State centralizado y predecible; un único punto de mutación.
- Efectos cancelables (`.cancellable(id:)`) para recargas por región/filtro y debounce.

### 2.2 Dependencias inyectables

`APIClient`, `LocationClient`, `AdClient`, `FavoritesClient` como `@Dependency` con `liveValue`/`testValue` (RFC §3.2, §3.3).

Justificación:
- Testeo de reducers con `TestStore` y dependencias mockeadas, sin red ni CoreLocation reales.

---

## 3. Consecuencias

### Archivos creados
- `Features/Map/MapFeature.swift`, `Features/Filters/FiltersFeature.swift`, `Features/StationDetail/StationDetailFeature.swift`, `App/AppFeature.swift`.
- `Core/Network/APIClient.swift`, `Core/Location/LocationClient.swift`, `Core/Ads/AdClient.swift` (como `DependencyKey`).

### Tests requeridos
- `TestStore` por reducer (acción→estado, efectos).

### Riesgo
- Boilerplate de TCA → aceptado; lo compensa la testabilidad y la familiaridad del equipo.
- Curva de `Map` iOS17 + TCA bindings → mitigado con `@Bindable`/`BindingReducer`.

### No incluido (decisión explícita)
- No MVVM ni MV (descartados; ver §5).
- No Combine para lógica nueva (async/await + efectos TCA).

---

## 4. Plan de migración (orden recomendado)
1. **Crear** dependencias (`APIClient`, `LocationClient`) con test/live values.
2. **Crear** `MapFeature` + `MapView`, luego `Filters` y `StationDetail`.
3. **Componer** en `AppFeature`.
4. **Tests** con `TestStore` (delegado a QA).

---

## 5. Alternativas consideradas

### Para §2.1
- **Opción A (elegida)**: TCA. Estado predecible, efectos cancelables, testeo fuerte, experiencia del equipo.
- **Opción B (rechazada)**: MVVM + `@Observable`. — **Razón**: menos infraestructura de test/efectos; el equipo prefiere TCA para esta complejidad.
- **Opción C (rechazada)**: MV vanilla. — **Razón**: se queda corto con la lógica de mapa/filtros/efectos.

---

## 6. Estimación
Transversal a FM-7…FM-11.

---

## 7. Referencias
- RFC: `.claude/rfc/RFC-001-fuelmap-architecture.md` §1, §3, §6.2
- swift-composable-architecture (Point-Free)
