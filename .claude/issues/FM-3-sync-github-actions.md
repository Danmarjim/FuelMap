# FM-3: Job de sync MIMIT en GitHub Actions

> Derivado de RFC-001 §6.3, ADR-001, ADR-003. Self-contained.

## Description
Implementar el job diario que descarga los CSV del MIMIT, los parsea (separador `|`), normaliza `descCarburante`, valida coordenadas, hace upsert en Supabase y registra telemetría en `sync_runs`. Mantiene los datos frescos y el proyecto Supabase activo.

Complexity: L
Dependencies: FM-2

## Files to Modify
- `/backend/sync/index.*` (nuevo) — lógica de descarga/parse/normalización/upsert.
- `/backend/sync/fuel-mapping.*` (nuevo) — tabla de mapeo `descCarburante`→`FuelType` (ADR-003).
- `/.github/workflows/sync-mimit.yml` (nuevo) — cron `30 6 * * *` UTC + run manual (`workflow_dispatch`).
- `/backend/package.json` o `requirements.txt`.

## Technical Specification (from RFC)
**Source:** RFC §6.3, §2.1; ADR-003.

URLs (verificadas 2026-06-04):
- `https://www.mimit.gov.it/images/exportCSV/anagrafica_impianti_attivi.csv`
- `https://www.mimit.gov.it/images/exportCSV/prezzo_alle_8.csv`

Reglas de parsing:
- **Separador `|` (pipe)** — NO `;` (cambió el 2026-02-10).
- `anagrafica`: 1ª línea `Estrazione del YYYY-MM-DD` → saltar y capturar fecha en `sync_runs.extraction_date`. Header: `idImpianto|Gestore|Bandiera|Tipo Impianto|Nome Impianto|Indirizzo|Comune|Provincia|Latitudine|Longitudine`.
- `prezzo`: header `idImpianto|descCarburante|prezzo|isSelf|dtComu`. `isSelf` 1=self/0=servito. `dtComu` formato `DD/MM/YYYY HH:MM:SS`.
- Construir `location` desde Lat/Lng; **descartar filas con coords vacías/0/fuera de rango** (NF6) y contar descartes.
- Normalizar `descCarburante`→`FuelType` con tabla de mapeo; guardar `fuel_raw`; loggear no-mapeadas (→`altro`) en `sync_runs.notes`.
- Upsert `stations` (on conflict id); **reemplazo transaccional** de `prices` por run.

Secrets: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` (GitHub Secrets).

## What NOT to Do
- Do NOT usar `;` como separador.
- Do NOT insertar estaciones sin coordenadas válidas.
- Do NOT hacer diff de precios (reemplazo total por run).
- Do NOT exponer la `service_role key` fuera de GitHub Secrets.

## Tests to Add
- Parse de fixtures: CSV con línea `Estrazione`, separador `|`, filas con coords inválidas, variantes de combustible conocidas y desconocidas.

```
parse_anagrafica_skipsEstrazioneLine
parse_anagrafica_discardsInvalidCoords
parse_prezzo_parsesSelfFlagAndTimestamp
fuelMapping_knownVariants / fuelMapping_unknownFallsBackToAltroAndLogs
```

Mock/stub strategy: fixtures CSV locales; mock del cliente Supabase para asserts de upsert.

## Status: CÓDIGO HECHO + PARSER VERIFICADO CONTRA DATOS REALES (2026-06-05) — despliegue pendiente

> `backend/sync/` (Node 22): `parse.mjs`, `fuel-mapping.mjs` (ADR-003), `sync.mjs`, `sync.test.mjs`; `.github/workflows/sync-mimit.yml`. Verificado contra los CSV reales del MIMIT: 23.707 stations válidas / 106 descartadas / 0 malformed; 93.050 precios / 0 skipped; normalización correcta; `→altro` loggeadas. El upsert a Supabase no se ejecuta sin proyecto cloud.

## Acceptance Criteria
- [x] Parser CSV pipe-separated (salta `Estrazione`+cabecera), validación coords, normalización fuel, dtComu. **Verificado con datos reales.**
- [x] Filas sin coords válidas descartadas y contadas (106 reales).
- [x] Variantes no mapeadas → `altro` y registradas (HiQ Perform+, F101…).
- [x] `sync.mjs` upsert stations + reemplazo prices + `sync_runs`; workflow falla en error.
- [x] Tests pass (node --test, 3).
- [ ] **(runbook)** Ciclo `workflow_dispatch` real puebla Supabase (requiere secrets + proyecto).

## References
- RFC: §6.3, §2.1
- ADR-001, ADR-003
