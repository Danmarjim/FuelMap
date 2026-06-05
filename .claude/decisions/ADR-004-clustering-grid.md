# ADR-004: Clustering de pins por grid en el reducer (vs MKMapView)

> Fecha: 2026-06-05
> Estado: Aceptado
> Contexto: FM-15. La premisa del RFC §5 ("clustering nativo de `Map`") es falsa — SwiftUI `Map` (iOS 17) no clusteriza annotations custom. Detectado en la evaluación multi-agente (review C2).

---

## 1. Contexto

PRD F6 (Must-have) pide clustering. SwiftUI `Map` no agrupa annotations propias. Con ~22k estaciones reales el mapa sería inusable sin agrupar. **Pero** la RPC `nearby_stations` limita a 200 filas por consulta, así que el cliente nunca renderiza más de ~200 pins a la vez: el problema de escala está acotado.

---

## 2. Decisión

Clustering **por celdas de una rejilla, calculado en el reducer** como función pura, manteniendo el `Map` de SwiftUI.

### 2.1 `MapClustering.items(stations:span:)`

Función pura: agrupa estaciones en celdas cuyo tamaño es proporcional al zoom visible (`span * 0.07`). Celda con 1 estación → `.station`; con ≥2 → `.cluster` (centroide + conteo + precio más barato). `MapItem` (enum) se renderiza en el `Map`.

```swift
enum MapItem: Identifiable, Equatable { case station(Station); case cluster(StationCluster) }
```

### 2.2 Zoom/desagrupado

`mapCameraChanged` captura el `span` real de la cámara; al hacer zoom las celdas se reducen y los clusters se deshacen. Tap en cluster → `clusterTapped` reduce el span y recentra (zoom in).

Justificación:
- Dataset acotado (≤200 por la RPC) → clustering trivial en coste.
- Mantiene `Map` SwiftUI nativo (`UserAnnotation`, `mapControls`, `safeAreaInset` de filtros) sin reescritura.
- Lógica **pura y testeable** en TCA (encaja con la arquitectura; cubierta por `MapClusteringTests`).

---

## 3. Consecuencias

### Archivos
- `Features/Map/MapClustering.swift` (`MapItem`, `StationCluster`, algoritmo), `Features/Map/ClusterPin.swift`.
- `MapFeature`: `span` actualizado desde la cámara, `mapItems` computado, `clusterTapped`.
- `MapView`: render por `mapItems` con `@MapContentBuilder`.

### Riesgo
- Des-agrupado menos "nativo" que MapKit (sin animación de split). Aceptable.
- Celdas en grados (no metros) → leve distorsión con la latitud; irrelevante a escala urbana.

### No incluido
- `MKMapView`+`MKClusterAnnotation` (ver §5).
- Cluster que conserve el highlight de "más barata" (el verde reaparece al desagrupar).

---

## 4. Alternativas consideradas

- **Opción A (elegida)**: grid clustering en el reducer. Testeable, sin reescritura, suficiente para ≤200 pins.
- **Opción B (rechazada)**: `MKMapView` (UIViewRepresentable) + `MKClusterAnnotation`. Clustering nativo y animado, pero exige reescribir el mapa, plumbing de delegate→TCA, render de pins en `MKAnnotationView`, y pierde la `Map` SwiftUI. Sobredimensionado dado el límite de 200. Reconsiderar si en el futuro se renderizan miles de pins simultáneos (p. ej. carga por viewport en vez de por radio).

---

## 5. Estimación
Hecho en FM-15 (~medio día).

## 6. Referencias
- Review: `.claude/reviews/2026-06-05-evaluacion-completa.md` (C2)
- RFC §5, §6.2, §11; PRD F6
