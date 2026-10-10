-- Logger device pairing + ride source for M5Stack hardware ingest.

create table if not exists public.logger_devices (
  device_id text primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  secret_hash text not null,
  label text,
  last_seen_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists logger_devices_user_idx
  on public.logger_devices (user_id);

alter table public.logger_devices enable row level security;

drop policy if exists logger_devices_select_own on public.logger_devices;
create policy logger_devices_select_own
  on public.logger_devices for select
  using (user_id = auth.uid());

drop policy if exists logger_devices_insert_own on public.logger_devices;
create policy logger_devices_insert_own
  on public.logger_devices for insert
  with check (user_id = auth.uid());

drop policy if exists logger_devices_update_own on public.logger_devices;
create policy logger_devices_update_own
  on public.logger_devices for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists logger_devices_delete_own on public.logger_devices;
create policy logger_devices_delete_own
  on public.logger_devices for delete
  using (user_id = auth.uid());

-- Short-lived pairing codes minted by the app.
create table if not exists public.logger_pair_codes (
  code text primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists logger_pair_codes_user_idx
  on public.logger_pair_codes (user_id);

alter table public.logger_pair_codes enable row level security;

drop policy if exists logger_pair_codes_select_own on public.logger_pair_codes;
create policy logger_pair_codes_select_own
  on public.logger_pair_codes for select
  using (user_id = auth.uid());

drop policy if exists logger_pair_codes_insert_own on public.logger_pair_codes;
create policy logger_pair_codes_insert_own
  on public.logger_pair_codes for insert
  with check (user_id = auth.uid());

alter table public.rides
  add column if not exists source text not null default 'phone';

comment on column public.rides.source is
  'phone | m5_logger | import — origin of the ride track';

create index if not exists rides_user_source_idx
  on public.rides (user_id, source);
