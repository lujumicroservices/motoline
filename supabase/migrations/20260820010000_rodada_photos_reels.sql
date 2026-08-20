-- Rodada photo metadata for auto-link (time/GPS) + shareable reels.

alter table public.rodada_photos
  add column if not exists taken_at timestamptz,
  add column if not exists ride_id uuid references public.rides (id) on delete set null,
  add column if not exists source text
    check (source is null or source in ('camera', 'gallery')),
  add column if not exists content_hash text;

create index if not exists rodada_photos_ride_idx
  on public.rodada_photos (ride_id)
  where ride_id is not null;

create unique index if not exists rodada_photos_hash_uidx
  on public.rodada_photos (rodada_id, user_id, content_hash)
  where content_hash is not null;

create table if not exists public.rodada_reels (
  id uuid primary key default gen_random_uuid(),
  rodada_id uuid not null references public.rodadas (id) on delete cascade,
  ride_id uuid references public.rides (id) on delete set null,
  user_id uuid not null references public.profiles (id) on delete cascade,
  storage_path text not null,
  duration_ms integer not null default 0,
  hook_kind text not null default 'lean'
    check (hook_kind in ('lean', 'photo')),
  created_at timestamptz not null default now()
);

create index if not exists rodada_reels_rodada_idx
  on public.rodada_reels (rodada_id, created_at desc);

alter table public.rodada_reels enable row level security;

drop policy if exists rodada_reels_select on public.rodada_reels;
create policy rodada_reels_select
  on public.rodada_reels for select
  using (public.is_rodada_member(rodada_id));

drop policy if exists rodada_reels_insert on public.rodada_reels;
create policy rodada_reels_insert
  on public.rodada_reels for insert
  with check (
    user_id = auth.uid() and public.is_rodada_member(rodada_id)
  );

drop policy if exists rodada_reels_delete on public.rodada_reels;
create policy rodada_reels_delete
  on public.rodada_reels for delete
  using (
    user_id = auth.uid() or public.is_rodada_host_or_cohost(rodada_id)
  );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'rodada-reels',
  'rodada-reels',
  false,
  41943040,
  array['video/mp4']
)
on conflict (id) do nothing;

drop policy if exists rodada_reels_storage_select on storage.objects;
create policy rodada_reels_storage_select
  on storage.objects for select
  using (
    bucket_id = 'rodada-reels'
    and public.is_rodada_member((storage.foldername(name))[1]::uuid)
  );

drop policy if exists rodada_reels_storage_insert on storage.objects;
create policy rodada_reels_storage_insert
  on storage.objects for insert
  with check (
    bucket_id = 'rodada-reels'
    and auth.uid()::text = (storage.foldername(name))[2]
    and public.is_rodada_member((storage.foldername(name))[1]::uuid)
  );

drop policy if exists rodada_reels_storage_delete on storage.objects;
create policy rodada_reels_storage_delete
  on storage.objects for delete
  using (
    bucket_id = 'rodada-reels'
    and (
      auth.uid()::text = (storage.foldername(name))[2]
      or public.is_rodada_host_or_cohost((storage.foldername(name))[1]::uuid)
    )
  );
