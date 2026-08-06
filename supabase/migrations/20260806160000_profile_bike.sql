-- Rider garage bike (Triumph catalog id) for lean / compare context.
alter table public.profiles
  add column if not exists bike_id text;

comment on column public.profiles.bike_id is
  'Catalog bike id (e.g. triumph_street_triple_765) from the mobile app.';
