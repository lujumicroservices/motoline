-- Barometer pressure per GPS sample (phone sensor, hectopascals).
alter table public.track_points
  add column if not exists pressure_hpa double precision;
