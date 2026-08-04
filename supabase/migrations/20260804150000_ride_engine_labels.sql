-- Structured beta labels for lean / curve / brake engine training.
-- Phones also mirror via camera_events (category = engine_label).

create table if not exists public.ride_engine_labels (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  ride_local_id text not null,
  phone_mount text not null,
  lean_quality text,
  brake_feel text,
  ride_context text,
  notes text,
  payload jsonb not null default '{}'::jsonb,
  labeled_at timestamptz not null default now(),
  unique (user_id, ride_local_id)
);

create index if not exists ride_engine_labels_user_labeled_idx
  on public.ride_engine_labels (user_id, labeled_at desc);

create index if not exists ride_engine_labels_mount_idx
  on public.ride_engine_labels (phone_mount);

alter table public.ride_engine_labels enable row level security;

create policy "ride_engine_labels_select_own"
  on public.ride_engine_labels for select
  using (user_id = auth.uid());

create policy "ride_engine_labels_insert_own"
  on public.ride_engine_labels for insert
  with check (user_id = auth.uid());

create policy "ride_engine_labels_update_own"
  on public.ride_engine_labels for update
  using (user_id = auth.uid());
