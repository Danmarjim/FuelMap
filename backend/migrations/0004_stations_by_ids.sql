-- FuelMap — RPC de precios por lote de IDs (favoritos con precio en vivo)
-- Devuelve, para un conjunto de estaciones (favoritos), las filas de precio del
-- combustible pedido (mismo shape que nearby_stations → reutiliza NearbyStationRowDTO
-- + StationMapper en el cliente). Filtra fuel/self en servidor; distance_m = 0
-- (la distancia se calcula en el cliente desde la ubicación del usuario).
-- Idempotente (create or replace). Aplicar en el SQL editor de Supabase.

create or replace function public.stations_by_ids(
    in_ids bigint[],
    in_fuel text,
    in_self_only boolean default false
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
           0::double precision as distance_m
    from public.stations s
    join public.prices p on p.station_id = s.id
    where s.id = any(in_ids)
      and p.fuel = in_fuel
      and (not in_self_only or p.is_self = true)
    order by s.id, p.price asc;
$$;

grant execute on function public.stations_by_ids(bigint[], text, boolean)
    to anon, authenticated;
