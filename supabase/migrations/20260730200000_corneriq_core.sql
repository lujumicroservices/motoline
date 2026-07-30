-- CornerIQ cloud schema (separate from Luju POS / auto).
-- Auth users own profiles; rides sync from device SQLite; shared rides enable peer compare.

create extension if not exists "pgcrypto";

-- Rider profile (1:1 with auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Named route / circuit (loop tagging later)
create table if not exists public.routes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  name text not null,
  description text,
  -- Optional loop anchors (WGS84)
  init_lat double precision,
  init_lng double precision,
  end_lat double precision,
  end_lng double precision,
  geofence_radius_m double precision not null default 40,
  is_shared boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists routes_owner_idx on public.routes (owner_id);
create index if not exists routes_shared_idx on public.routes (is_shared) where is_shared;

-- Synced ride summary (device id kept for idempotent upsert)
create table if not exists public.rides (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  route_id uuid references public.routes (id) on delete set null,
  local_id text not null,
  started_at timestamptz not null,
  ended_at timestamptz,
  distance_meters double precision not null default 0,
  point_count integer not null default 0,
  max_speed_mps double precision,
  avg_speed_mps double precision,
  max_lean_left_deg double precision,
  max_lean_right_deg double precision,
  line_score integer,
  is_shared boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, local_id)
);

create index if not exists rides_user_idx on public.rides (user_id, started_at desc);
create index if not exists rides_route_shared_idx on public.rides (route_id, is_shared)
  where route_id is not null and is_shared;

-- Dense GPS/lean samples (chunked sync from phone)
create table if not exists public.track_points (
  id bigserial primary key,
  ride_id uuid not null references public.rides (id) on delete cascade,
  recorded_at timestamptz not null,
  latitude double precision not null,
  longitude double precision not null,
  altitude double precision,
  speed_mps double precision,
  accuracy_meters double precision,
  heading double precision,
  lean_degrees double precision
);

create index if not exists track_points_ride_idx
  on public.track_points (ride_id, recorded_at);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- RLS
alter table public.profiles enable row level security;
alter table public.routes enable row level security;
alter table public.rides enable row level security;
alter table public.track_points enable row level security;

-- Profiles
create policy "profiles_select_own_or_shared_peer"
  on public.profiles for select
  using (
    id = auth.uid()
    or exists (
      select 1 from public.rides r
      where r.user_id = profiles.id and r.is_shared = true
    )
  );

create policy "profiles_update_own"
  on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "profiles_insert_own"
  on public.profiles for insert
  with check (id = auth.uid());

-- Routes
create policy "routes_select_own_or_shared"
  on public.routes for select
  using (owner_id = auth.uid() or is_shared = true);

create policy "routes_insert_own"
  on public.routes for insert
  with check (owner_id = auth.uid());

create policy "routes_update_own"
  on public.routes for update
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "routes_delete_own"
  on public.routes for delete
  using (owner_id = auth.uid());

-- Rides
create policy "rides_select_own_or_shared"
  on public.rides for select
  using (user_id = auth.uid() or is_shared = true);

create policy "rides_insert_own"
  on public.rides for insert
  with check (user_id = auth.uid());

create policy "rides_update_own"
  on public.rides for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "rides_delete_own"
  on public.rides for delete
  using (user_id = auth.uid());

-- Track points follow parent ride visibility
create policy "track_points_select_via_ride"
  on public.track_points for select
  using (
    exists (
      select 1 from public.rides r
      where r.id = track_points.ride_id
        and (r.user_id = auth.uid() or r.is_shared = true)
    )
  );

create policy "track_points_insert_own_ride"
  on public.track_points for insert
  with check (
    exists (
      select 1 from public.rides r
      where r.id = track_points.ride_id and r.user_id = auth.uid()
    )
  );

create policy "track_points_delete_own_ride"
  on public.track_points for delete
  using (
    exists (
      select 1 from public.rides r
      where r.id = track_points.ride_id and r.user_id = auth.uid()
    )
  );
