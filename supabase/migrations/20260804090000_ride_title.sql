-- Optional human ride title from start/end reverse-geocode (e.g. Cañadas - Moyahua).
alter table public.rides
  add column if not exists title text;
