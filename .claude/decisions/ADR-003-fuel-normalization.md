# ADR-003: Normalización de `descCarburante` en el sync con preservación de `fuel_raw`

> Fecha: 2026-06-04
> Estado: Aceptado
> Contexto: RFC-001 §5, §6.3. Decisión sobre el tratamiento del campo de tipo de combustible del MIMIT.

---

## 1. Contexto

El CSV `prezzo_alle_8.csv` del MIMIT trae `descCarburante` como **texto libre** con muchas variantes: `Benzina`, `Gasolio`, `Metano`, `GPL`, y premium como `Hi-Q Diesel`, `Blue Super`, `HVO`, etc. El cliente necesita un conjunto cerrado y limpio para el selector de combustible y para filtrar la RPC. Mapear en cliente acoplaría la app a la heterogeneidad de la fuente y rompería ante variantes nuevas.

---

## 2. Decisión

Normalizar `descCarburante` **en el job de sync**, guardando además el valor original.

### 2.1 Enum cerrado en cliente + columna doble en BD

`FuelType { benzina, gasolio, gpl, metano, hvo }` (más `altro` como fallback). En `prices`: columna `fuel` (normalizada, la que consulta la RPC) y `fuel_raw` (original, auditoría).

```swift
enum FuelType: String, Sendable, CaseIterable { case benzina, gasolio, gpl, metano, hvo, altro }
```

### 2.2 Tabla de mapeo en el sync + log de no-mapeadas

El sync aplica una tabla de mapeo (substring/regex case-insensitive) `descCarburante → FuelType`. Variantes no reconocidas → `altro` y se registran en `sync_runs.notes` para revisión.

Justificación:
- El cliente recibe un enum estable; el selector de combustible no depende de la fuente.
- `fuel_raw` permite auditar y refinar el mapeo sin perder información.
- El log de no-mapeadas evita silencios: nuevas variantes se detectan, no se pierden.

---

## 3. Consecuencias

### Archivos creados/afectados
- `/backend/sync/fuel-mapping.*` — tabla de mapeo.
- Esquema `prices`: columnas `fuel` + `fuel_raw` (RFC §2.1).
- iOS: `Core/Models/FuelType.swift`.

### Tests requeridos
- Mapeo de variantes conocidas + fallback `altro`; verificación de log de no-mapeadas.

### Riesgo
- Mapeo incompleto ante variantes futuras → mitigado por fallback `altro` (no rompe el sync) + log en `sync_runs`.
- Agrupar premium bajo una categoría base puede ocultar matices de precio → aceptado en v1; reevaluar si el usuario pide granularidad premium.

### No incluido (decisión explícita)
- No mapeo en cliente.
- No exponer todas las variantes premium como tipos separados en v1.

---

## 4. Plan de migración (orden recomendado)
1. **Definir** tabla de mapeo y `FuelType`.
2. **Aplicar** en el sync (FM-3), poblando `fuel` + `fuel_raw`.
3. **Consumir** `FuelType` en cliente (FM-4, FM-8).
4. **Tests** de mapeo (delegado a QA).

---

## 5. Alternativas consideradas

### Para §2.1
- **Opción A (elegida)**: normalizar en sync + `fuel_raw`. Cliente limpio, auditoría preservada.
- **Opción B (rechazada)**: mapear en cliente. — **Razón**: acopla la app a la fuente; cada variante nueva requiere release de app.
- **Opción C (rechazada)**: exponer texto crudo. — **Razón**: selector y filtros inconsistentes; mala UX.

---

## 6. Estimación
Incluido en FM-3 (~medio día del trabajo de sync).

---

## 7. Referencias
- RFC: `.claude/rfc/RFC-001-fuelmap-architecture.md` §2.1, §6.3
- ADR-001 (capa de datos / sync)
- MIMIT `prezzo_alle_8.csv` (verificado 2026-06-04)
