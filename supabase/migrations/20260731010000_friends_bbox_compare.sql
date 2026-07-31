-- Closed-beta friends (all profiles visible) + ride bbox for same-area compare.

alter table public.rides
  add column if not exists min_lat double precision,
  add column if not exists max_lat double precision,
  add column if not exists min_lng double precision,
  add column if not exists max_lng double precision;

create index if not exists rides_bbox_shared_idx
  on public.rides (is_shared, min_lat, max_lat, min_lng, max_lng)
  where is_shared and min_lat is not null;

-- Closed beta: every authenticated rider can see every profile (friend list = all users).
drop policy if exists "profiles_select_own_or_shared_peer" on public.profiles;

create policy "profiles_select_authenticated"
  on public.profiles for select
  using (auth.uid() is not null);

-- Peer rides whose bbox intersects the query bbox (with pad ≈ 250 m at mid latitudes).
create or replace function public.rides_overlapping(
  p_min_lat double precision,
  p_max_lat double precision,
  p_min_lng double precision,
  p_max_lng double precision,
  p_exclude_ride_id uuid default null,
  p_pad_deg double precision default 0.0025
)
returns setof public.rides
language sql
stable
security invoker
as $$
  select r.*
  from public.rides r
  where r.is_shared = true
    and r.min_lat is not null
    and r.max_lat is not null
    and r.min_lng is not null
    and r.max_lng is not null
    and r.user_id is distinct from auth.uid()
    and (p_exclude_ride_id is null or r.id is distinct from p_exclude_ride_id)
    and r.min_lat <= (p_max_lat + p_pad_deg)
    and r.max_lat >= (p_min_lat - p_pad_deg)
    and r.min_lng <= (p_max_lng + p_pad_deg)
    and r.max_lng >= (p_min_lng - p_pad_deg)
  order by r.started_at desc;
$$;

grant execute on function public.rides_overlapping(
  double precision,
  double precision,
  double precision,
  double precision,
  uuid,
  double precision
) to authenticated;
