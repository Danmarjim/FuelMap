# ADR-001: Capa de datos vía Supabase + sync por GitHub Actions (sin backend propio)

> Fecha: 2026-06-04
> Estado: Aceptado
> Contexto: RFC-001 §5. Decisión fundacional de la arquitectura de datos de FuelMap.
> Motivación: el usuario quiere una app robusta para App Store sin operar un servidor propio.

---

## 1. Contexto

Los datos oficiales del MIMIT son dos CSV diarios (~22k impianti + cientos de miles de precios), pipe-separated, con `descCarburante` en texto libre. Resolver "estaciones en radio de N km" exige índice geoespacial; parsear los CSV en el dispositivo es inviable por tamaño y por la falta de query espacial. No queremos operar un servidor propio (coste/mantenimiento), pero sí necesitamos una API geoespacial robusta y datos frescos a diario.

---

## 2. Decisión

Adoptar una capa de datos gestionada con dos piezas coordinadas, sin servidor propio:

### 2.1 Supabase (PostgreSQL + PostGIS) como API de lectura

Tablas `stations`, `prices`, `sync_runs` (RFC §2.1). RPC `nearby_stations(lat,lng,radius_km,fuel,self_only,limit)` (RFC §3.1) con `ST_DWithin` sobre `geography(Point,4326)` indexado con GIST. RLS: rol `anon` solo `SELECT`/ejecución de la RPC (read-only). La app usa la `anon key`.

Justificación:
- Coste ~0€ en free tier (500 MB DB, API ilimitada, 5 GB egress/mes) — holgado para el volumen.
- PostGIS da query espacial indexada sin código de servidor propio.
- API REST/RPC autogenerada → cliente Swift directo con `supabase-swift`.

### 2.2 Sync diario con GitHub Actions

Workflow cron (~08:30 CEST) descarga los CSV del MIMIT, normaliza y hace upsert con la `service_role key` (GitHub Secret). Telemetría en `sync_runs`. Código en monorepo `/backend`.

Justificación:
- Gratis, versionado y con logs/alertas nativas de GitHub.
- La escritura diaria mantiene el proyecto free **activo** (evita la pausa por inactividad de 1 semana).
- Reemplazo transaccional de `prices` por run: los precios cambian masivamente a diario, el diff no aporta.

---

## 3. Consecuencias

### Archivos creados
- `/backend/migrations/0001_init.sql` — esquema + RPC + RLS.
- `/backend/sync/` — script de descarga/parse/normalización/upsert.
- `/.github/workflows/sync-mimit.yml` — cron diario.
- iOS: `Core/Network/APIClient.swift` consume la RPC.

### Tests requeridos
- Parse de fixtures CSV (pipe, línea `Estrazione`, variantes fuel) en `/backend`.
- RPC `nearby_stations` contra DB seed (pgTAP/SQL).

### Riesgo
- Egress free (5 GB/mes) limitado a escala → mitigado con JSON ligero, `limit`, debounce de región; upgrade Pro $25/mes si se supera.
- Dependencia de la estabilidad del endpoint/formato MIMIT → parser tolerante + alerta en `sync_runs` (ver ADR-003).

### No incluido (decisión explícita)
- No backend propio (Node/Fastify/VPS).
- No API wrapper de terceros (Render free = cold starts, sin SLA).
- No scraping de Osservaprezzi (frágil, zona gris legal).

---

## 4. Plan de migración (orden recomendado)
1. **Crear** esquema Supabase + RPC + RLS (FM-2).
2. **Crear** script de sync + workflow (FM-3) y verificar un ciclo completo.
3. **Conectar** APIClient iOS a la RPC (FM-5).
4. **Tests** de parse y RPC (delegado a QA).

---

## 5. Alternativas consideradas

### Para §2.1 / §2.2
- **Opción A (elegida)**: Supabase + GitHub Actions. Coste 0€, sin operar servidor, geo indexado.
- **Opción B (rechazada)**: Backend propio Node/Fastify + Postgres en Railway. — **Razón**: ~5€/mes y mantenimiento/operación que no aporta sobre Supabase.
- **Opción C (rechazada)**: API wrapper de terceros (Render). — **Razón**: cold starts, sin SLA, dependencia de un servicio que puede desaparecer.
- **Opción D (rechazada)**: CSV en cliente. — **Razón**: inviable por tamaño y sin query espacial.

---

## 6. Estimación
FM-2 (~medio día) + FM-3 (~1-2 días) de trabajo enfocado.

---

## 7. Referencias
- RFC: `.claude/rfc/RFC-001-fuelmap-architecture.md` §1, §2, §3, §5, §6.3
- PRD: `.claude/prd/PRD-001-fuelmap.md`
- Supabase pricing: https://supabase.com/pricing
- MIMIT Open Data (CSV pipe `|`, IODL 2.0)
