-- FuelMap — RPC de detalle de estación (FM-5)
-- Devuelve TODOS los combustibles de una estación (mismo shape que nearby_stations,
-- reutiliza NearbyStationRowDTO + StationMapper en el cliente). distance_m = 0.
-- Idempotente (create or replace). Aplicar en el SQL editor de Supabase.

create or replace function public.station_detail(in_id bigint)
returns table (
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
           0::double precision as distance_m
    from public.stations s
    join public.prices p on p.station_id = s.id
    where s.id = in_id
    order by p.fuel, p.is_self;
$$;

grant execute on function public.station_detail(bigint) to anon, authenticated;
