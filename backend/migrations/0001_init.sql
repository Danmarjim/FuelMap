-- FuelMap — esquema inicial (FM-2)
-- Supabase (PostgreSQL + PostGIS). Aplicar en el SQL editor de Supabase o vía CLI.
-- RFC-001 §2.1 (esquema), §3.1 (RPC). ADR-001 (capa de datos).

create extension if not exists postgis;

-- ── Tablas ──────────────────────────────────────────────────────────────────

-- Impianti (upsert diario desde anagrafica_impianti_attivi.csv)
create table if not exists public.stations (
    id           bigint primary key,             -- idImpianto
    manager      text,                           -- Gestore
    brand        text,                           -- Bandiera
    type         text,                           -- Tipo Impianto (Stradale/Autostradale)
    name         text,                           -- Nome Impianto
    address      text,                           -- Indirizzo
    municipality text,                           -- Comune
    province     text,                           -- Provincia (sigla)
    location     geography(Point, 4326) not null,-- desde Latitudine/Longitudine
    country      char(2) not null default 'IT',  -- agnóstico al país (escalabilidad)
    updated_at   timestamptz not null default now()
);
create index if not exists stations_location_gix on public.stations using gist (location);
create index if not exists stations_province_idx on public.stations (province);

-- Precios (reemplazo diario desde prezzo_alle_8.csv)
create table if not exists public.prices (
    station_id      bigint not null references public.stations(id) on delete cascade,
    fuel            text   not null,             -- descCarburante normalizado (ADR-003)
    fuel_raw        text   not null,             -- descCarburante original (auditoría)
    price           numeric(6,3) not null,
    is_self         boolean not null,            -- isSelf 1=self / 0=servito
    communicated_at timestamptz,                 -- dtComu
    primary key (station_id, fuel_raw, is_self)
);
create index if not exists prices_lookup_idx on public.prices (fuel, is_self);
create index if not exists prices_station_idx on public.prices (station_id);

-- Telemetría del sync (observabilidad)
create table if not exists public.sync_runs (
    id                bigserial primary key,
    started_at        timestamptz not null default now(),
    finished_at       timestamptz,
    stations_upserted int,
    prices_upserted   int,
    stations_discarded int,                      -- coords inválidas (NF6)
    extraction_date   date,                      -- "Estrazione del ..."
    status            text,                      -- ok | partial | error
    notes             text
);

-- ── RPC geoespacial (RFC §3.1) ────────────────────────────────────────────────

create or replace function public.nearby_stations(
    in_lat double precision,
    in_lng double precision,
    in_radius_km double precision,
    in_fuel text,
    in_self_only boolean default false,
    in_limit int default 200
) returns table (
    id bigint, name text, brand text, address text,
    municipality text, province text,
    latitude double precision, longitude double precision,
    fuel text, price numeric, is_self boolean,
    communicated_at timestamptz, distance_m double precision
)
language sql
stable
set search_path = public
as $$
    select s.id, s.name, s.brand, s.address, s.municipality, s.province,
           st_y(s.location::geometry) as latitude,
           st_x(s.location::geometry) as longitude,
           p.fuel, p.price, p.is_self, p.communicated_at,
           st_distance(s.location, st_makepoint(in_lng, in_lat)::geography) as distance_m
    from public.stations s
    join public.prices p on p.station_id = s.id
    where p.fuel = in_fuel
      and (not in_self_only or p.is_self = true)
      and st_dwithin(s.location, st_makepoint(in_lng, in_lat)::geography, in_radius_km * 1000)
    order by p.price asc
    limit in_limit;
$$;

-- ── RLS: el rol anónimo solo lee (la app usa la anon key) ─────────────────────

alter table public.stations  enable row level security;
alter table public.prices    enable row level security;
-- sync_runs: RLS habilitado SIN políticas → solo service_role (el sync) accede;
-- anon/authenticated quedan bloqueados (es telemetría, no se expone a la app).
alter table public.sync_runs enable row level security;

drop policy if exists "anon read stations" on public.stations;
create policy "anon read stations" on public.stations
    for select to anon, authenticated using (true);

drop policy if exists "anon read prices" on public.prices;
create policy "anon read prices" on public.prices
    for select to anon, authenticated using (true);

-- Privilegios de tabla (RLS no concede por sí solo el privilegio SELECT)
grant select on public.stations to anon, authenticated;
grant select on public.prices   to anon, authenticated;
grant execute on function public.nearby_stations(
    double precision, double precision, double precision, text, boolean, int
) to anon, authenticated;

-- El sync usa la service_role key, que bypassa RLS (acceso total por defecto).
