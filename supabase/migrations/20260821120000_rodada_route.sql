-- Planned road-follow itinerary for a rodada (Valhalla geometry + prefs).

alter table public.rodadas
  add column if not exists route_geometry text,
  add column if not exists route_distance_m double precision,
  add column if not exists route_duration_s double precision,
  add column if not exists route_prefs jsonb,
  add column if not exists route_provider text;
