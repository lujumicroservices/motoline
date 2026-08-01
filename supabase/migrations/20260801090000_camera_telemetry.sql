-- Camera lab troubleshooting telemetry (events + config snapshots).
-- Syncs from the phone so remote debugging does not depend on device logs.

create table if not exists public.camera_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  local_id text not null,
  ride_local_id text,
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null,
  uploaded_at timestamptz not null default now(),
  unique (user_id, local_id)
);

create index if not exists camera_events_user_created_idx
  on public.camera_events (user_id, created_at desc);

create index if not exists camera_events_ride_local_idx
  on public.camera_events (user_id, ride_local_id)
  where ride_local_id is not null;

create table if not exists public.camera_config_snapshots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  ride_local_id text,
  prefs jsonb not null,
  zones jsonb not null default '[]'::jsonb,
  camera_group jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists camera_config_snapshots_user_created_idx
  on public.camera_config_snapshots (user_id, created_at desc);

alter table public.camera_events enable row level security;
alter table public.camera_config_snapshots enable row level security;

create policy "camera_events_select_own"
  on public.camera_events for select
  using (user_id = auth.uid());

create policy "camera_events_insert_own"
  on public.camera_events for insert
  with check (user_id = auth.uid());

create policy "camera_config_snapshots_select_own"
  on public.camera_config_snapshots for select
  using (user_id = auth.uid());

create policy "camera_config_snapshots_insert_own"
  on public.camera_config_snapshots for insert
  with check (user_id = auth.uid());
