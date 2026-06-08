# QA Coverage Review — RESTYLE-001
**Fecha:** 2026-06-08  
**Diff base:** `0fb77cd..HEAD`  
**Tests en suite:** 53 (Swift Testing)  
**Evaluador:** ios-qa

---

## Resumen ejecutivo

El restyle introduce lógica nueva testeable en tres áreas: `PriceTier` (propiedades de forma/etiqueta), `MapStyleOption` (control de capas) y dos funciones privadas de `StationDetailView` (`variantRows` y la lógica "mejor precio" self/servito). Las dos primeras están cubiertas. La tercera no lo está por estar embebida en una vista, pero contiene ramas de ordenación y selección de mejor precio que justifican extraerlas o testearlas indirectamente. El resto del restyle (DesignSystem, pins, sheets, filtros) es UI pura sin lógica extraíble adicional.

---

## Tabla de cobertura

| Área | Archivo | Cubierto | Riesgo | Test sugerido |
|---|---|---|---|---|
| `PriceTier.symbolName` / `label` | `PriceTiers.swift` | ✅ Sí — `tier_shapeAndLabel` en `UXEnrichmentTests` | Bajo | — |
| `PriceTier.fill` / `ink` / `surface` / `color` (alias) | `PriceTiers.swift` | ⚠️ Parcial — `fill`/`ink`/`surface` no se afirman; `color` alias no probado | Bajo (valores de Color no comparables en unit test) | No worth: `Color` wraps asset catalog, no tiene valor Equatable significativo en unit |
| `PriceTiers` terciles + degenerado | `PriceTiers.swift` | ✅ Sí — 2 tests existentes + nuevo de forma/etiqueta | Bajo | — |
| `MapFeature.mapStyleChanged` reducer | `MapFeature.swift` | ✅ Sí — `map_mapStyleChanged_updatesState` en `MapFeatureTests` | Bajo | — |
| `MapStyleOption.label` / `symbol` | `MapFeature.swift` | ❌ No | Muy bajo (puras computed sobre `String(localized:)`) | No worth: constantes sin lógica ramificada |
| `DesignSystem/Spacing` | `Spacing.swift` | ❌ No | Muy bajo | No worth: namespace de constantes `CGFloat`; sin lógica |
| `DesignSystem/Radius` | `Radius.swift` | ❌ No | Muy bajo | No worth: idem |
| `DesignSystem/Typography` (Font extensions) | `Typography.swift` | ❌ No | Muy bajo | No worth: extensiones declarativas de `Font`; no tiene lógica ramificada |
| `DesignSystem/Elevation` (`ElevationModifier.params`) | `Elevation.swift` | ❌ No | Bajo | Extractable pero marginal: parámetros de sombra por nivel/colorScheme. No worth dado que son valores magic del CSS sin lógica de negocio. |
| `StationDetailView.variantRows` — agrupación por `fuelRaw`, orden (filtrado primero, luego nombre) | `StationDetailView.swift` | ❌ No | **Alto** | Ver test T1 abajo |
| `StationDetailView` — mejor precio self/servito (`isBest`) | `StationDetailView.swift` | ❌ No | **Medio** | Ver test T2 abajo |
| `StationDetailView.latestUpdate` — `max(communicatedAt)` | `StationDetailView.swift` | ❌ No | Bajo | Worth pero mínimo: un `compactMap.max()` sin ramas. Cubierto implícitamente por fixtures. |
| `StationListView.distanceText` — formato m/km | `StationListView.swift` | ❌ No | **Medio** | Ver test T3 abajo |
| `StationListView.voiceOverLabel` — composición de partes | `StationListView.swift` | ❌ No | Bajo | Ver test T4 abajo (worth: lógica de strings VoiceOver) |
| `FreshnessPill.stale` — umbral 2 días | `SheetComponents.swift` | ❌ No | **Medio** | Ver test T5 abajo |
| `StationPin.accessibilityText` | `StationPin.swift` | ❌ No | Bajo | Worth: lógica de strings a11y con ramas (isCheapest, monogram vacío). Ver T6. |
| `BrandBadge` | `BrandBadge.swift` | N/A (UI pura, sin lógica extraíble) | Ninguno | No worth |
| `ClusterPin` | `ClusterPin.swift` | N/A (UI pura) | Ninguno | No worth |
| `SheetComponents` (TierTag, BestFlag, SortPill, SheetHeader, SkeletonRow/List) | `SheetComponents.swift` | N/A (UI pura) | Ninguno | No worth |
| `FiltersView.canStep` / `stepRadius` | `FiltersView.swift` | ❌ No | **Medio** | Ver test T7 abajo |
| Regresión `PriceTiers` terciles pre-restyle | `UXEnrichmentTests` | ✅ Cubierto por tests previos | Ninguno | — |
| Regresión `BrandStyle.from` | `UXEnrichmentTests` | ✅ Cubierto | Ninguno | — |
| Regresión `MapFeature` (onAppear, debounce, etc.) | `MapFeatureTests` | ✅ Cubierto | Ninguno | — |
| Regresión `StationDetailFeature` (load, favorite, navigate) | `StationDetailFeatureTests` | ✅ Cubierto | Ninguno | — |

---

## Análisis de riesgo: lógica embebida en vistas

### Problema estructural

`variantRows(for:)`, `latestUpdate(for:)`, `distanceText(to:)` y `voiceOverLabel(for:)` son funciones `private` de `View` structs. No son accesibles directamente desde tests. Hay dos vías para cubrirlas:

1. **Extraer a un tipo puro testeable** (helper struct o función libre). Preferible si la lógica crece.
2. **Test indirecto** a través del `StationDetailFeature` / `StationListView` con fixtures construidas a medida. Para variantRows, el `StationDetailFeature` expone `station` vía `store.state.station`, por lo que se puede verificar el efecto de la agrupación inspeccionando los precios. Sin embargo, la ordenación del filtro activo ("primero el filtrado") y el cálculo de `isBest` son puramente de vista y no se pueden afirmar desde el reducer.

**Recomendación**: para T1 y T2, el camino más pragmático a corto plazo es extraer `variantRows` a una función libre/helper con `internal` visibility. Es un cambio de 3 líneas en producción y desbloquea tests directos de alto valor. Si el developer prefiere no tocar la vista, anotar como riesgo aceptado.

### `FreshnessPill.stale` y `FiltersView.canStep`

Son propiedades privadas de vistas. `stale` computa sobre `Date.now` (dependencia implícita del tiempo). `canStep` opera sobre `RadiusOption.all` (array estático). Para testear `stale` habría que inyectar el clock o mover la propiedad fuera de la vista.

---

## Tests de alto valor recomendados

### T1 — `variantRows`: agrupación y ordenación `[ALTO]`

**Justificación:** La lógica de agrupar `FuelPrice` por `fuelRaw` y ordenar el combustible filtrado primero es no trivial y actualmente invisible a los tests. Un cambio aquí podría mostrar precios en orden incorrecto o mezclar self/servito de fuelRaw distintos.

**Prerrequisito:** Extraer `variantRows` a `internal` o función libre. Si no, test indirecto insuficiente.

```swift
// StationDetailVariantRowsTests.swift
@Test("Agrupa fuelRaw distintos en filas separadas manteniendo self/servito")
func variantRows_groupsByFuelRaw()

@Test("El combustible filtrado aparece primero; el resto por nombre")
func variantRows_selectedFuelSortsFirst()

@Test("Estación sin precios devuelve array vacío")
func variantRows_emptyPrices_returnsEmpty()
```

---

### T2 — Mejor precio self/servito (`isBest`) `[MEDIO]`

**Justificación:** La lógica `best = [selfPrice, servitoPrice].compactMap { $0 }.min()` + `isBest: row.selfPrice == best` determina qué precio se muestra en `priceCheapInk`. Casos edge: solo self, solo servito, ambos iguales, ambos nil.

**Prerrequisito:** Igual que T1 (lógica embebida en `priceRow`). Extraer o añadir visibility.

```swift
@Test("isBest marca self cuando self < servito")
func isBest_selfCheaper_marksSelf()

@Test("isBest marca servito cuando servito < self")
func isBest_servitoIsCheaper_marksServito()

@Test("Cuando solo hay un tipo, ese es el mejor")
func isBest_onlyOneVariant_alwaysBest()
```

---

### T3 — `distanceText`: formato m/km `[MEDIO]`

**Justificación:** Umbral en 1000 m, formato con 1 decimal en km. Actualmente en `StationListView` como `private`. También usada en `voiceOverLabel` (VoiceOver anuncia la distancia). Un off-by-one aquí afecta a la accesibilidad.

**Prerrequisito:** Extraer a extensión de `Coordinate` o función libre con visibility `internal`.

```swift
@Test("Distancia < 1000 m se formatea en metros")
@Test("Distancia >= 1000 m se formatea en km con 1 decimal")
@Test("Exactamente 1000 m usa km (no 1000 m)")
```

---

### T5 — `FreshnessPill.stale`: umbral de 2 días `[MEDIO]`

**Justificación:** `stale = date < Date.now - 2d` determina el color/icono de la píldora de frescura. El umbral de 2 días es una decisión de negocio. Si se cambia accidentalmente, los precios obsoletos dejan de marcarse en warning sin que ningún test lo detecte.

**Prerrequisito:** Mover `stale` a una función libre pura `func isPriceStale(_ date: Date, now: Date) -> Bool`. Coste: 2 líneas de producción.

```swift
@Test("Precio de hace 1 día NO es stale")
@Test("Precio de hace 49 horas SÍ es stale (supera las 48 h)")
@Test("Exactamente 48 h es stale (boundary)")
```

---

### T7 — `FiltersView.canStep`: límites del stepper de radio `[MEDIO]`

**Justificación:** `canStep(-1)` en el primer elemento y `canStep(+1)` en el último deben retornar false para deshabilitar los botones. Si falla, el stepper puede salir del array y crashear. La lógica es privada en la vista pero opera sobre `RadiusOption.all` (dato accesible).

**Prerrequisito:** Extraer a función libre o helper testeable.

```swift
@Test("canStep(-1) false en el primer radio (1 km)")
@Test("canStep(+1) false en el último radio (20 km)")
@Test("canStep en radio intermedio permite ambas direcciones")
@Test("radio fuera del array → canStep devuelve true (fallback seguro)")
```

---

### T4 — `voiceOverLabel`: composición correcta `[BAJO-MEDIO]`

**Justificación:** El label de VoiceOver incluye nombre, distancia, precio, tier y badge "più economico". Un cambio de orden o una rama omitida degrada la experiencia de usuarios con VoiceOver.

```swift
@Test("voiceOverLabel incluye nombre, distancia, precio y tier")
@Test("voiceOverLabel añade 'più economico' solo si isCheapest")
@Test("voiceOverLabel omite precio si la estación no tiene precios")
```

---

### T6 — `StationPin.accessibilityText` `[BAJO]`

**Justificación:** Similar a T4 pero para el pin del mapa. La propiedad es `private` en la vista. Tiene ramas (monogram vacío, isCheapest). Bajo riesgo porque el pin es una vista simple y el texto se ve en el preview.

```swift
@Test("accessibilityText incluye tier label")
@Test("accessibilityText incluye 'il più economico' si isCheapest")
@Test("accessibilityText sin monograma no incluye nombre de marca")
```

---

## Verificación de regresiones

Revisada la lógica existente que podría haber sido afectada por el restyle:

| Área | Veredicto |
|---|---|
| `PriceTiers` terciles — sin cambios en la lógica de umbrales | Sin regresión |
| `MapFeature` reducer — `mapStyleChanged` es adición pura; resto sin tocar | Sin regresión |
| `StationDetailFeature` reducer — `StationDetailView` renombró funciones de vista pero el reducer no cambió | Sin regresión |
| `FiltersFeature` reducer — sin cambios en lógica (solo vista) | Sin regresión |
| `BrandStyle.from` — sin cambios en el diff | Sin regresión |
| `StationMapper` — no tocado en el diff | Sin regresión |
| `Station.cheapest` — no tocado en el diff | Sin regresión |
| `Decimal.fuelPriceLabel` — no tocado en el diff | Sin regresión |
| `color` alias en `PriceTier` — mantenido como `{ fill }`, retro-compatible | Sin regresión |

---

## Recomendación final

**Cobertura actual: SUFICIENTE para el restyle como capa visual.** Los dos tests añadidos (`tier_shapeAndLabel`, `map_mapStyleChanged_updatesState`) cubren correctamente la lógica nueva más crítica del restyle.

**Añadir 3 tests concretos antes de cierre de fase** (el resto son opcionales o requieren refactor de producción):

1. **T5 — `isPriceStale` (umbral 48 h)** — Requiere extraer 2 líneas de `FreshnessPill`. Alto retorno por mínimo esfuerzo: protege una decisión de UX (warning de precio obsoleto) con fecha exacta de negocio.

2. **T1 — `variantRows` agrupación** — Requiere dar `internal` a la función en `StationDetailView`. La lógica de agrupar por `fuelRaw` + ordenar el filtro activo primero es la transformación de datos más compleja introducida en el restyle; sin test es el único punto donde una regresión sería completamente invisible.

3. **T3 — `distanceText` formato m/km** — Requiere extraer a extensión de `Coordinate`. Protege el VoiceOver de la lista (anuncia distancia) y el umbral 1000 m, que también impacta a usuarios videntes.

Los tests T2, T4, T6, T7 son worth pero de menor urgencia; se pueden diferir a la siguiente fase de mantenimiento.
