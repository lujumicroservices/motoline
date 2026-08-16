-- Family / watch: trusted circle + per-ride watch session + magic-link tokens.
-- Web viewers call get_watch_public(token) as anon (security definer).

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- Trusted contacts (circle)
-- ---------------------------------------------------------------------------

create table if not exists public.trusted_contacts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  contact_user_id uuid references public.profiles (id) on delete cascade,
  display_label text not null,
  status text not null default 'active'
    check (status in ('active', 'pending', 'revoked')),
  see_live boolean not null default true,
  get_ok_ping boolean not null default true,
  get_sos boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    contact_user_id is null
    or contact_user_id <> owner_id
  )
);

create index if not exists trusted_contacts_owner_idx
  on public.trusted_contacts (owner_id, status);
create unique index if not exists trusted_contacts_owner_user_uidx
  on public.trusted_contacts (owner_id, contact_user_id)
  where contact_user_id is not null and status <> 'revoked';

alter table public.trusted_contacts enable row level security;

drop policy if exists trusted_contacts_owner_all on public.trusted_contacts;
create policy trusted_contacts_owner_all
  on public.trusted_contacts for all
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists trusted_contacts_contact_select on public.trusted_contacts;
create policy trusted_contacts_contact_select
  on public.trusted_contacts for select
  using (
    contact_user_id = auth.uid()
    and status = 'active'
  );

-- ---------------------------------------------------------------------------
-- Watch sessions
-- ---------------------------------------------------------------------------

create table if not exists public.watch_sessions (
  id uuid primary key default gen_random_uuid(),
  rider_id uuid not null references public.profiles (id) on delete cascade,
  local_ride_id text,
  cloud_ride_id uuid,
  status text not null default 'active'
    check (status in ('active', 'ended', 'cancelled')),
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  rider_display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists watch_sessions_rider_idx
  on public.watch_sessions (rider_id, status, started_at desc);
create index if not exists watch_sessions_local_ride_idx
  on public.watch_sessions (rider_id, local_ride_id);

alter table public.watch_sessions enable row level security;

drop policy if exists watch_sessions_rider_all on public.watch_sessions;
create policy watch_sessions_rider_all
  on public.watch_sessions for all
  using (rider_id = auth.uid())
  with check (rider_id = auth.uid());

drop policy if exists watch_sessions_contact_select on public.watch_sessions;
create policy watch_sessions_contact_select
  on public.watch_sessions for select
  using (
    exists (
      select 1
      from public.trusted_contacts c
      where c.owner_id = watch_sessions.rider_id
        and c.contact_user_id = auth.uid()
        and c.status = 'active'
        and c.see_live = true
    )
  );

-- ---------------------------------------------------------------------------
-- Last-known position per session
-- ---------------------------------------------------------------------------

create table if not exists public.watch_positions (
  session_id uuid primary key references public.watch_sessions (id) on delete cascade,
  latitude double precision not null,
  longitude double precision not null,
  speed_mps double precision,
  heading double precision,
  updated_at timestamptz not null default now()
);

alter table public.watch_positions enable row level security;

drop policy if exists watch_positions_rider_all on public.watch_positions;
create policy watch_positions_rider_all
  on public.watch_positions for all
  using (
    exists (
      select 1 from public.watch_sessions s
      where s.id = watch_positions.session_id
        and s.rider_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.watch_sessions s
      where s.id = watch_positions.session_id
        and s.rider_id = auth.uid()
        and s.status = 'active'
    )
  );

drop policy if exists watch_positions_contact_select on public.watch_positions;
create policy watch_positions_contact_select
  on public.watch_positions for select
  using (
    exists (
      select 1
      from public.watch_sessions s
      join public.trusted_contacts c
        on c.owner_id = s.rider_id
       and c.contact_user_id = auth.uid()
       and c.status = 'active'
       and c.see_live = true
      where s.id = watch_positions.session_id
    )
  );

-- ---------------------------------------------------------------------------
-- Events (ok / stopped / sos / ended)
-- ---------------------------------------------------------------------------

create table if not exists public.watch_events (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.watch_sessions (id) on delete cascade,
  kind text not null
    check (kind in ('started', 'ok', 'stopped', 'sos', 'ended', 'cancelled')),
  note text,
  created_at timestamptz not null default now()
);

create index if not exists watch_events_session_idx
  on public.watch_events (session_id, created_at desc);

alter table public.watch_events enable row level security;

drop policy if exists watch_events_rider_all on public.watch_events;
create policy watch_events_rider_all
  on public.watch_events for all
  using (
    exists (
      select 1 from public.watch_sessions s
      where s.id = watch_events.session_id
        and s.rider_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.watch_sessions s
      where s.id = watch_events.session_id
        and s.rider_id = auth.uid()
    )
  );

drop policy if exists watch_events_contact_select on public.watch_events;
create policy watch_events_contact_select
  on public.watch_events for select
  using (
    exists (
      select 1
      from public.watch_sessions s
      join public.trusted_contacts c
        on c.owner_id = s.rider_id
       and c.contact_user_id = auth.uid()
       and c.status = 'active'
      where s.id = watch_events.session_id
        and (
          (watch_events.kind in ('ok', 'stopped', 'started', 'ended', 'cancelled')
            and c.get_ok_ping = true)
          or (watch_events.kind = 'sos' and c.get_sos = true)
          or c.see_live = true
        )
    )
  );

-- ---------------------------------------------------------------------------
-- Magic-link tokens (store hash only)
-- ---------------------------------------------------------------------------

create table if not exists public.watch_share_tokens (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.watch_sessions (id) on delete cascade,
  token_hash text not null unique,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz
);

create index if not exists watch_share_tokens_session_idx
  on public.watch_share_tokens (session_id);

alter table public.watch_share_tokens enable row level security;

drop policy if exists watch_share_tokens_rider_all on public.watch_share_tokens;
create policy watch_share_tokens_rider_all
  on public.watch_share_tokens for all
  using (
    exists (
      select 1 from public.watch_sessions s
      where s.id = watch_share_tokens.session_id
        and s.rider_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.watch_sessions s
      where s.id = watch_share_tokens.session_id
        and s.rider_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- Public read by raw token (anon + authenticated)
-- ---------------------------------------------------------------------------

create or replace function public.get_watch_public(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_hash text;
  v_tok public.watch_share_tokens%rowtype;
  v_sess public.watch_sessions%rowtype;
  v_pos public.watch_positions%rowtype;
  v_events jsonb;
begin
  if p_token is null or length(trim(p_token)) < 16 then
    return jsonb_build_object('ok', false, 'error', 'invalid_token');
  end if;

  v_hash := encode(digest(convert_to(trim(p_token), 'UTF8'), 'sha256'), 'hex');

  select * into v_tok
  from public.watch_share_tokens t
  where t.token_hash = v_hash
  limit 1;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;

  if v_tok.revoked_at is not null or v_tok.expires_at < now() then
    return jsonb_build_object('ok', false, 'error', 'expired');
  end if;

  select * into v_sess from public.watch_sessions s where s.id = v_tok.session_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;

  select * into v_pos from public.watch_positions p where p.session_id = v_sess.id;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'kind', e.kind,
      'note', e.note,
      'created_at', e.created_at
    ) order by e.created_at desc
  ), '[]'::jsonb)
  into v_events
  from (
    select * from public.watch_events ev
    where ev.session_id = v_sess.id
    order by ev.created_at desc
    limit 20
  ) e;

  return jsonb_build_object(
    'ok', true,
    'session', jsonb_build_object(
      'id', v_sess.id,
      'status', v_sess.status,
      'started_at', v_sess.started_at,
      'ended_at', v_sess.ended_at,
      'rider_display_name', coalesce(v_sess.rider_display_name, 'Rider')
    ),
    'position', case when v_pos.session_id is null then null else jsonb_build_object(
      'latitude', v_pos.latitude,
      'longitude', v_pos.longitude,
      'speed_mps', v_pos.speed_mps,
      'heading', v_pos.heading,
      'updated_at', v_pos.updated_at
    ) end,
    'events', v_events,
    'expires_at', v_tok.expires_at
  );
end;
$$;

revoke all on function public.get_watch_public(text) from public;
grant execute on function public.get_watch_public(text) to anon, authenticated;
