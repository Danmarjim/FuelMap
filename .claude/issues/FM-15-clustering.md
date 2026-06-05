# FM-15: Clustering de pins en el mapa

> Derivado de la evaluación multi-agente (2026-06-05) y PRD F6 (Must-have).
> Origen: la premisa del RFC §5 ("clustering nativo de `Map`") es falsa — SwiftUI `Map` (iOS 17) no clusteriza annotations custom.

## Description
Implementar clustering de gasolineras en el mapa. **Bloqueante antes de conectar datos reales** (~22k impianti): sin clustering, con el `limit` de la RPC (~200) el mapa renderiza cientos de pins sueltos, degradando UX y rendimiento. Con el mock (6 estaciones) no se aprecia, por eso se difirió.

Complexity: L
Dependencies: FM-7

## Technical Specification
**Source:** RFC §1, §5, §6.2 (addendum §11); PRD F6.

SwiftUI `Map` no agrupa annotations custom. Opciones:
1. **`MKMapView` vía `UIViewRepresentable`** + `MKClusterAnnotation` (`MKMarkerAnnotationView.clusteringIdentifier`). Control total, clustering nativo de MapKit. Mayor coste de integración con TCA (delegate → acciones).
2. **Clustering por grid en el reducer**: agrupar `stations` por celda según el `span` actual y renderizar un pin-cluster (con conteo) por celda; al hacer zoom, desagrupar. Mantiene SwiftUI `Map`.

Decisión de enfoque → **ADR** al arrancar el issue (recomendado evaluar opción 1 primero por fidelidad).

## What NOT to Do
- No romper el flujo TCA actual (filtros, recentrado, selección → detalle) al introducir MKMapView.
- No clusterizar a ciegas sin probar rendimiento con un dataset grande (seed de cientos de estaciones).

## Status: DONE (2026-06-05) — grid clustering en el reducer (ADR-004)

> Enfoque elegido: clustering por celdas en función pura (`MapClustering.items(stations:span:)`), manteniendo `Map` SwiftUI (no MKMapView). Dataset acotado por el `limit 200` de la RPC. Verificación visual limpia pendiente de tap manual (overlay de consentimiento bloquea headless); lógica cubierta por tests.

## Acceptance Criteria
- [x] Pins cercanos se agrupan en clusters con conteo (`ClusterPin`).
- [x] Al hacer zoom (span de la cámara) los clusters se desagrupan; tap en cluster → `clusterTapped` reduce span + recentra.
- [x] Tap en pin individual → detalle (flujo intacto).
- [x] Coste trivial (≤200 pins por la RPC); función pura.
- [x] Tests: `MapClusteringTests` (4) + `clusterTapped`; 45 tests totales. SwiftLint 0.

## References
- Review: `.claude/reviews/2026-06-05-evaluacion-completa.md` (C2)
- RFC §5, §6.2, §11; PRD F6
