-- FuelMap — exponer fuel_raw en las RPC (variante real del producto) — opción A
-- El nombre original del MIMIT (p. ej. "Benzina Plus 98") ya está en prices.fuel_raw;
-- aquí lo devolvemos para mostrarlo en el detalle. Idempotente (create or replace).
-- No requiere re-sync. Aplicar en el SQL editor de Supabase.

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
    fuel text, fuel_raw text, price numeric, is_self boolean,
    communicated_at timestamptz, distance_m double precision
)
language sql
stable
set search_path = public
as $$
    select s.id, s.name, s.brand, s.address, s.municipality, s.province,
           st_y(s.location::geometry) as latitude,
           st_x(s.location::geometry) as longitude,
           p.fuel, p.fuel_raw, p.price, p.is_self, p.communicated_at,
           st_distance(s.location, st_makepoint(in_lng, in_lat)::geography) as distance_m
    from public.stations s
    join public.prices p on p.station_id = s.id
    where p.fuel = in_fuel
      and (not in_self_only or p.is_self = true)
      and st_dwithin(s.location, st_makepoint(in_lng, in_lat)::geography, in_radius_km * 1000)
    order by p.price asc
    limit in_limit;
$$;

create or replace function public.station_detail(in_id bigint)
returns table (
    id bigint, name text, brand text, address text,
    municipality text, province text,
    latitude double precision, longitude double precision,
    fuel text, fuel_raw text, price numeric, is_self boolean,
    communicated_at timestamptz, distance_m double precision
)
language sql
stable
set search_path = public
as $$
    select s.id, s.name, s.brand, s.address, s.municipality, s.province,
           st_y(s.location::geometry) as latitude,
           st_x(s.location::geometry) as longitude,
           p.fuel, p.fuel_raw, p.price, p.is_self, p.communicated_at,
           0::double precision as distance_m
    from public.stations s
    join public.prices p on p.station_id = s.id
    where s.id = in_id
    order by p.fuel, p.fuel_raw, p.is_self;
$$;
