-- Planned itinerary: finish pin on the rodada + ordered stops.

alter table public.rodadas
  add column if not exists finish_lat double precision,
  add column if not exists finish_lng double precision;

alter table public.rodada_stops
  add column if not exists sort_order int not null default 0;

create index if not exists rodada_stops_order_idx
  on public.rodada_stops (rodada_id, sort_order, created_at);
