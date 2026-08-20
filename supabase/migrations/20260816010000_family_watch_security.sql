-- Family Watch security: access audit, rate limit, refuse ended sessions.

create table if not exists public.watch_share_access (
  id uuid primary key default gen_random_uuid(),
  token_id uuid not null references public.watch_share_tokens (id) on delete cascade,
  session_id uuid not null references public.watch_sessions (id) on delete cascade,
  accessed_at timestamptz not null default now()
);

create index if not exists watch_share_access_token_recent_idx
  on public.watch_share_access (token_id, accessed_at desc);

create index if not exists watch_share_access_session_idx
  on public.watch_share_access (session_id, accessed_at desc);

alter table public.watch_share_access enable row level security;

-- Rider can audit who opened their links (RPC still writes as definer).
drop policy if exists watch_share_access_rider_select on public.watch_share_access;
create policy watch_share_access_rider_select
  on public.watch_share_access for select
  using (
    exists (
      select 1 from public.watch_sessions s
      where s.id = watch_share_access.session_id
        and s.rider_id = auth.uid()
    )
  );

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
  v_recent int;
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

  -- Soft rate limit: ~1 req/s sustained per token (bursts up to 60/min).
  select count(*)::int into v_recent
  from public.watch_share_access a
  where a.token_id = v_tok.id
    and a.accessed_at > now() - interval '1 minute';

  if v_recent >= 60 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;

  select * into v_sess from public.watch_sessions s where s.id = v_tok.session_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;

  if v_sess.status <> 'active' then
    return jsonb_build_object('ok', false, 'error', 'ended');
  end if;

  insert into public.watch_share_access (token_id, session_id)
  values (v_tok.id, v_sess.id);

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
