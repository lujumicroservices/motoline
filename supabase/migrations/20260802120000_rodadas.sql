-- Group rides (Rodadas): membership, live GPS, photos, radio, stops.
-- Social data is membership-scoped (not global is_shared).

-- ---------------------------------------------------------------------------
-- Core
-- ---------------------------------------------------------------------------

create table if not exists public.rodadas (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  destination text,
  notes text,
  meetup_lat double precision,
  meetup_lng double precision,
  starts_at timestamptz,
  status text not null default 'open'
    check (status in ('draft', 'open', 'live', 'ended')),
  invite_code text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists rodadas_host_idx on public.rodadas (host_id);
create index if not exists rodadas_status_starts_idx
  on public.rodadas (status, starts_at);
create index if not exists rodadas_invite_code_idx
  on public.rodadas (invite_code);

create table if not exists public.rodada_members (
  rodada_id uuid not null references public.rodadas (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null default 'rider'
    check (role in ('host', 'cohost', 'rider')),
  rsvp text not null default 'going'
    check (rsvp in ('going', 'maybe', 'declined', 'pending')),
  share_live boolean not null default false,
  share_track boolean not null default false,
  presence text not null default 'offline'
    check (presence in (
      'offline', 'idle', 'en_route', 'at_meetup', 'riding', 'stopped'
    )),
  joined_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (rodada_id, user_id)
);

create index if not exists rodada_members_user_idx
  on public.rodada_members (user_id);

create table if not exists public.rodada_live_positions (
  rodada_id uuid not null references public.rodadas (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  latitude double precision not null,
  longitude double precision not null,
  speed_mps double precision,
  heading double precision,
  presence text not null default 'riding',
  updated_at timestamptz not null default now(),
  primary key (rodada_id, user_id)
);

create index if not exists rodada_live_updated_idx
  on public.rodada_live_positions (rodada_id, updated_at desc);

create table if not exists public.rodada_photos (
  id uuid primary key default gen_random_uuid(),
  rodada_id uuid not null references public.rodadas (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  storage_path text not null,
  caption text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now()
);

create index if not exists rodada_photos_rodada_idx
  on public.rodada_photos (rodada_id, created_at desc);

create table if not exists public.rodada_messages (
  id uuid primary key default gen_random_uuid(),
  rodada_id uuid not null references public.rodadas (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  body text not null,
  kind text not null default 'text'
    check (kind in ('text', 'safety', 'system')),
  created_at timestamptz not null default now()
);

create index if not exists rodada_messages_rodada_idx
  on public.rodada_messages (rodada_id, created_at desc);

create table if not exists public.rodada_stops (
  id uuid primary key default gen_random_uuid(),
  rodada_id uuid not null references public.rodadas (id) on delete cascade,
  created_by uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  latitude double precision not null,
  longitude double precision not null,
  created_at timestamptz not null default now()
);

create index if not exists rodada_stops_rodada_idx
  on public.rodada_stops (rodada_id, created_at desc);

-- Link personal rides to a rodada (optional).
alter table public.rides
  add column if not exists rodada_id uuid references public.rodadas (id)
    on delete set null;

create index if not exists rides_rodada_idx
  on public.rides (rodada_id)
  where rodada_id is not null;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.is_rodada_member(p_rodada_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.rodada_members m
    where m.rodada_id = p_rodada_id
      and m.user_id = auth.uid()
  );
$$;

create or replace function public.is_rodada_host_or_cohost(p_rodada_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.rodada_members m
    where m.rodada_id = p_rodada_id
      and m.user_id = auth.uid()
      and m.role in ('host', 'cohost')
  );
$$;

create or replace function public.generate_rodada_invite_code()
returns text
language plpgsql
as $$
declare
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result text := '';
  i int;
begin
  for i in 1..6 loop
    result := result || substr(chars, 1 + floor(random() * length(chars))::int, 1);
  end loop;
  return result;
end;
$$;

-- Auto-add host as member
create or replace function public.rodada_after_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.rodada_members (
    rodada_id, user_id, role, rsvp, share_live, share_track, presence
  ) values (
    new.id, new.host_id, 'host', 'going', false, false, 'idle'
  )
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists rodada_after_insert_trg on public.rodadas;
create trigger rodada_after_insert_trg
  after insert on public.rodadas
  for each row execute function public.rodada_after_insert();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.rodadas enable row level security;
alter table public.rodada_members enable row level security;
alter table public.rodada_live_positions enable row level security;
alter table public.rodada_photos enable row level security;
alter table public.rodada_messages enable row level security;
alter table public.rodada_stops enable row level security;

-- Rodadas: members see; anyone authenticated can peek by invite_code via RPC;
-- host creates; host/cohost update; host delete.
drop policy if exists rodadas_select_member on public.rodadas;
create policy rodadas_select_member
  on public.rodadas for select
  using (public.is_rodada_member(id) or host_id = auth.uid());

drop policy if exists rodadas_insert_auth on public.rodadas;
create policy rodadas_insert_auth
  on public.rodadas for insert
  with check (host_id = auth.uid());

drop policy if exists rodadas_update_host on public.rodadas;
create policy rodadas_update_host
  on public.rodadas for update
  using (public.is_rodada_host_or_cohost(id))
  with check (public.is_rodada_host_or_cohost(id));

drop policy if exists rodadas_delete_host on public.rodadas;
create policy rodadas_delete_host
  on public.rodadas for delete
  using (host_id = auth.uid());

-- Members
drop policy if exists rodada_members_select on public.rodada_members;
create policy rodada_members_select
  on public.rodada_members for select
  using (public.is_rodada_member(rodada_id));

drop policy if exists rodada_members_insert_self on public.rodada_members;
create policy rodada_members_insert_self
  on public.rodada_members for insert
  with check (
    user_id = auth.uid()
    or public.is_rodada_host_or_cohost(rodada_id)
  );

drop policy if exists rodada_members_update on public.rodada_members;
create policy rodada_members_update
  on public.rodada_members for update
  using (
    user_id = auth.uid()
    or public.is_rodada_host_or_cohost(rodada_id)
  )
  with check (
    user_id = auth.uid()
    or public.is_rodada_host_or_cohost(rodada_id)
  );

drop policy if exists rodada_members_delete on public.rodada_members;
create policy rodada_members_delete
  on public.rodada_members for delete
  using (
    user_id = auth.uid()
    or public.is_rodada_host_or_cohost(rodada_id)
  );

-- Live positions: only members; write own only when share_live
drop policy if exists rodada_live_select on public.rodada_live_positions;
create policy rodada_live_select
  on public.rodada_live_positions for select
  using (public.is_rodada_member(rodada_id));

drop policy if exists rodada_live_upsert_own on public.rodada_live_positions;
create policy rodada_live_upsert_own
  on public.rodada_live_positions for insert
  with check (
    user_id = auth.uid()
    and public.is_rodada_member(rodada_id)
    and exists (
      select 1 from public.rodada_members m
      where m.rodada_id = rodada_live_positions.rodada_id
        and m.user_id = auth.uid()
        and m.share_live = true
    )
  );

drop policy if exists rodada_live_update_own on public.rodada_live_positions;
create policy rodada_live_update_own
  on public.rodada_live_positions for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists rodada_live_delete_own on public.rodada_live_positions;
create policy rodada_live_delete_own
  on public.rodada_live_positions for delete
  using (user_id = auth.uid() or public.is_rodada_host_or_cohost(rodada_id));

-- Photos / messages / stops: members
drop policy if exists rodada_photos_select on public.rodada_photos;
create policy rodada_photos_select
  on public.rodada_photos for select
  using (public.is_rodada_member(rodada_id));

drop policy if exists rodada_photos_insert on public.rodada_photos;
create policy rodada_photos_insert
  on public.rodada_photos for insert
  with check (
    user_id = auth.uid() and public.is_rodada_member(rodada_id)
  );

drop policy if exists rodada_photos_delete on public.rodada_photos;
create policy rodada_photos_delete
  on public.rodada_photos for delete
  using (
    user_id = auth.uid() or public.is_rodada_host_or_cohost(rodada_id)
  );

drop policy if exists rodada_messages_select on public.rodada_messages;
create policy rodada_messages_select
  on public.rodada_messages for select
  using (public.is_rodada_member(rodada_id));

drop policy if exists rodada_messages_insert on public.rodada_messages;
create policy rodada_messages_insert
  on public.rodada_messages for insert
  with check (
    user_id = auth.uid() and public.is_rodada_member(rodada_id)
  );

drop policy if exists rodada_stops_select on public.rodada_stops;
create policy rodada_stops_select
  on public.rodada_stops for select
  using (public.is_rodada_member(rodada_id));

drop policy if exists rodada_stops_insert on public.rodada_stops;
create policy rodada_stops_insert
  on public.rodada_stops for insert
  with check (
    created_by = auth.uid()
    and public.is_rodada_host_or_cohost(rodada_id)
  );

drop policy if exists rodada_stops_delete on public.rodada_stops;
create policy rodada_stops_delete
  on public.rodada_stops for delete
  using (public.is_rodada_host_or_cohost(rodada_id));

-- Rides visible to rodada members when linked + owner share_track
drop policy if exists rides_select_rodada_member on public.rides;
create policy rides_select_rodada_member
  on public.rides for select
  using (
    rodada_id is not null
    and public.is_rodada_member(rodada_id)
    and exists (
      select 1 from public.rodada_members m
      where m.rodada_id = rides.rodada_id
        and m.user_id = rides.user_id
        and m.share_track = true
    )
  );

-- Track points follow rodada-linked ride visibility
drop policy if exists track_points_select_rodada on public.track_points;
create policy track_points_select_rodada
  on public.track_points for select
  using (
    exists (
      select 1 from public.rides r
      where r.id = track_points.ride_id
        and r.rodada_id is not null
        and public.is_rodada_member(r.rodada_id)
        and exists (
          select 1 from public.rodada_members m
          where m.rodada_id = r.rodada_id
            and m.user_id = r.user_id
            and m.share_track = true
        )
    )
  );

-- Profiles of co-members
drop policy if exists profiles_select_rodada_peer on public.profiles;
create policy profiles_select_rodada_peer
  on public.profiles for select
  using (
    exists (
      select 1
      from public.rodada_members me
      join public.rodada_members peer
        on peer.rodada_id = me.rodada_id
      where me.user_id = auth.uid()
        and peer.user_id = profiles.id
    )
  );

-- Join by invite code (security definer)
create or replace function public.join_rodada_by_code(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  rid uuid;
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  select id into rid
  from public.rodadas
  where upper(invite_code) = upper(trim(p_code))
    and status in ('draft', 'open', 'live')
  limit 1;
  if rid is null then
    raise exception 'Invalid invite code';
  end if;
  insert into public.rodada_members (rodada_id, user_id, role, rsvp)
  values (rid, uid, 'rider', 'going')
  on conflict (rodada_id, user_id) do update
    set rsvp = excluded.rsvp,
        updated_at = now();
  return rid;
end;
$$;

grant execute on function public.join_rodada_by_code(text) to authenticated;
grant execute on function public.is_rodada_member(uuid) to authenticated;
grant execute on function public.is_rodada_host_or_cohost(uuid) to authenticated;

-- Storage bucket for rodada photos (private; path = rodada_id/user_id/...)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'rodada-photos',
  'rodada-photos',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

drop policy if exists rodada_photos_storage_select on storage.objects;
create policy rodada_photos_storage_select
  on storage.objects for select
  using (
    bucket_id = 'rodada-photos'
    and public.is_rodada_member((storage.foldername(name))[1]::uuid)
  );

drop policy if exists rodada_photos_storage_insert on storage.objects;
create policy rodada_photos_storage_insert
  on storage.objects for insert
  with check (
    bucket_id = 'rodada-photos'
    and auth.uid()::text = (storage.foldername(name))[2]
    and public.is_rodada_member((storage.foldername(name))[1]::uuid)
  );

drop policy if exists rodada_photos_storage_delete on storage.objects;
create policy rodada_photos_storage_delete
  on storage.objects for delete
  using (
    bucket_id = 'rodada-photos'
    and (
      auth.uid()::text = (storage.foldername(name))[2]
      or public.is_rodada_host_or_cohost((storage.foldername(name))[1]::uuid)
    )
  );
