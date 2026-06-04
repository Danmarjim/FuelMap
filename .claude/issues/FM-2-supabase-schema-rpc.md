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

## Acceptance Criteria
- [ ] Migración aplica limpia sobre un proyecto Supabase nuevo.
- [ ] `nearby_stations(lat,lng,5,'benzina',false,200)` devuelve filas con `distance_m` y orden por precio.
- [ ] RLS: `anon` puede SELECT/RPC, no puede INSERT/UPDATE/DELETE.
- [ ] Índice GIST presente en `stations.location`.
- [ ] Tests pass.

## References
- RFC: `.claude/rfc/RFC-001-fuelmap-architecture.md` §2.1, §3.1
- ADR-001 (capa de datos)
