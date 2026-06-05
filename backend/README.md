# FuelMap — Backend (Supabase + sync MIMIT)

Capa de datos sin servidor propio (ADR-001): **Supabase** (PostgreSQL + PostGIS) +
**sync diario** por GitHub Actions desde los open data del MIMIT.

```
backend/
  migrations/0001_init.sql   # FM-2: esquema + PostGIS + RPC nearby_stations + RLS
  sync/                      # FM-3: descarga/parse/normaliza/upsert (Node 22)
    fuel-mapping.mjs         # descCarburante → FuelType (ADR-003)
    parse.mjs                # parse CSV pipe-separated (salta "Estrazione" + cabecera)
    sync.mjs                 # orquestador (usa @supabase/supabase-js)
    sync.test.mjs            # tests (node --test, sin red ni Supabase)
.github/workflows/sync-mimit.yml  # cron 06:30 UTC + workflow_dispatch
```

## Estado

- ✅ SQL, parser, sync y workflow **escritos**.
- ✅ Parser **verificado contra los CSV reales** del MIMIT (~22k stations, ~90k precios).
- ⏳ Pendiente (requiere tu cuenta): crear proyecto Supabase, aplicar migración,
  configurar GitHub Secrets y conectar la app iOS (FM-5 real).

## Runbook (pasos manuales)

### 1. Crear el proyecto Supabase
- Crea un proyecto en https://supabase.com (free tier).
- Anota: `Project URL`, `anon` key y `service_role` key (Settings → API).

### 2. Aplicar la migración
SQL editor del dashboard → pega `migrations/0001_init.sql` → Run.
(O con la CLI: `supabase db push` apuntando al proyecto.)

### 3. Probar el sync en local (opcional, recomendado)
```bash
cd backend/sync
npm install
node --test                         # tests del parser
SUPABASE_URL="https://xxxx.supabase.co" \
SUPABASE_SERVICE_ROLE_KEY="<service_role>" \
node sync.mjs                        # descarga real → upsert a tu Supabase
```
Verifica en el dashboard: tablas `stations`/`prices` pobladas y una fila en `sync_runs`.

### 4. Activar el sync automático (GitHub Actions)
- Crea el repo en GitHub y haz push (incluye `.github/workflows/sync-mimit.yml`).
- Settings → Secrets and variables → Actions → añade:
  - `SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
- Lanza el workflow manualmente (Actions → Sync MIMIT → Run workflow) para el primer poblado.

### 5. Conectar la app iOS (FM-5 real)
- Sustituir `APIClient.liveValue` (hoy mock) por la implementación sobre `supabase-swift`
  contra la RPC `nearby_stations`, usando `Project URL` + **anon key** (read-only por RLS).
- El contrato `APIClient` no cambia; es un swap de `liveValue`.

## Notas / decisiones
- Separador CSV `|` (desde 2026-02-10). Ambos ficheros traen 1ª línea `Estrazione del…`.
- `prices` se reemplaza por completo cada run (delete + insert; ventana breve no atómica,
  aceptable para un job diario).
- `communicated_at` se guarda como hora local naive (Europe/Rome) sin offset TZ — refinar
  si se necesita precisión horaria.
- Telemetría en `sync_runs` (contadores, fecha de extracción, variantes `→ altro`).
