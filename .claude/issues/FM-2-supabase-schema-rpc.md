# FM-2: Esquema Supabase + RPC geoespacial + RLS

> Derivado de RFC-001 §2.1, §3.1. Self-contained.

## Description
Crear el proyecto Supabase y el esquema PostgreSQL+PostGIS (`stations`, `prices`, `sync_runs`), la RPC `nearby_stations` y las políticas RLS read-only para el rol `anon`. Base de datos sobre la que opera el sync (FM-3) y la app (FM-5).

Complexity: M
Dependencies: None

## Files to Modify
- `/backend/migrations/0001_init.sql` (nuevo) — extensión PostGIS, tablas, índices, RPC, RLS.
- `/backend/README.md` (nuevo) — cómo aplicar migraciones y conectar.

## Technical Specification (from RFC)
**Source:** RFC §2.1 (esquema), §3.1 (RPC).

```sql
create extension if not exists postgis;
-- stations, prices, sync_runs: ver RFC §2.1 (copiar verbatim)
-- índices: gist(location), btree(province), (fuel,is_self), (station_id)
-- RPC nearby_stations(in_lat,in_lng,in_radius_km,in_fuel,in_self_only,in_limit): ver RFC §3.1
```

RLS:
- `stations`, `prices`: `enable row level security`; policy `anon` → `select` permitido.
- `nearby_stations`: `security definer` o ejecutable por `anon`.
- `service_role` (usado por el sync) bypassa RLS.

## What NOT to Do
- Do NOT escribir el script de sync (es FM-3).
- Do NOT exponer escritura al rol `anon`.
- Do NOT codificar la `service_role key` en el repo (irá en GitHub Secrets, FM-3).

## Tests to Add
- `nearby_stations` contra datos seed: devuelve estaciones dentro del radio ordenadas por precio asc; respeta `in_self_only` y `in_fuel`.

```sql
-- pgTAP o script SQL: seed 3 estaciones a distancias conocidas, assert orden y filtro
```

Mock/stub strategy: datos seed en una DB de prueba (no la de producción).

## Status: SQL ESCRITA (2026-06-05) — aplicación pendiente de proyecto Supabase (cloud)

> `backend/migrations/0001_init.sql`: esquema + PostGIS + RPC `nearby_stations` + RLS read-only (anon) + grants. No ejecutable en local (Docker no disponible → sin Supabase local). Aplicar vía dashboard/CLI (ver `backend/README.md`).

## Acceptance Criteria
- [x] Migración escrita (tablas, índices GIST, RPC, RLS, grants).
- [x] Migración aplicada en Supabase (2026-06-05).
- [x] `nearby_stations(...)` operativa con datos reales.
- [x] RLS aplicada; `sync_runs` solo service_role.

## References
- RFC: `.claude/rfc/RFC-001-fuelmap-architecture.md` §2.1, §3.1
- ADR-001 (capa de datos)
