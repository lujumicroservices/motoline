-- Re-archive current live activity and wipe operational tables again.
-- Safe to re-run. Keeps profiles / friendships / trusted_contacts / routes.
-- Refreshes history.rodada_photos if schema drifted (reels migration).

create schema if not exists history;

create table if not exists history.archive_batches (
  id uuid primary key,
  archived_at timestamptz not null default now(),
  note text,
  counts jsonb not null default '{}'::jsonb
);

alter table history.archive_batches enable row level security;

revoke all on schema history from public, anon, authenticated;
grant usage on schema history to postgres, service_role;

create or replace function history.ensure_clone(p_src regclass, p_dest text)
returns void
language plpgsql
as $$
begin
  if to_regclass(p_dest) is not null then
    return;
  end if;
  execute format(
    'create table %s (like %s including defaults including generated)',
    p_dest,
    p_src
  );
  execute format(
    'alter table %s
       add column archived_at timestamptz not null default now(),
       add column archive_batch_id uuid not null',
    p_dest
  );
  execute format('alter table %s enable row level security', p_dest);
end;
$$;

-- If public.rodada_photos gained columns after history clone, retire old clone.
do $$
declare
  live_cols int;
  hist_cols int;
begin
  select count(*) into live_cols
  from information_schema.columns
  where table_schema = 'public' and table_name = 'rodada_photos';

  select count(*) into hist_cols
  from information_schema.columns
  where table_schema = 'history' and table_name = 'rodada_photos';

  -- history has +2 archive cols; if live has more than hist-2, schema drifted.
  if hist_cols > 0 and live_cols > (hist_cols - 2) then
    execute 'alter table history.rodada_photos rename to rodada_photos_pre_'
      || to_char(now() at time zone 'utc', 'YYYYMMDDHH24MISS');
  end if;
end;
$$;

select history.ensure_clone('public.profiles', 'history.profiles');
select history.ensure_clone('public.rides', 'history.rides');
select history.ensure_clone('public.track_points', 'history.track_points');
select history.ensure_clone('public.ride_engine_labels', 'history.ride_engine_labels');
select history.ensure_clone('public.camera_events', 'history.camera_events');
select history.ensure_clone('public.camera_config_snapshots', 'history.camera_config_snapshots');
select history.ensure_clone('public.rodadas', 'history.rodadas');
select history.ensure_clone('public.rodada_members', 'history.rodada_members');
select history.ensure_clone('public.rodada_live_positions', 'history.rodada_live_positions');
select history.ensure_clone('public.rodada_photos', 'history.rodada_photos');
select history.ensure_clone('public.rodada_messages', 'history.rodada_messages');
select history.ensure_clone('public.rodada_stops', 'history.rodada_stops');
select history.ensure_clone('public.rodada_reels', 'history.rodada_reels');
select history.ensure_clone('public.watch_sessions', 'history.watch_sessions');
select history.ensure_clone('public.watch_positions', 'history.watch_positions');
select history.ensure_clone('public.watch_events', 'history.watch_events');
select history.ensure_clone('public.watch_share_tokens', 'history.watch_share_tokens');
select history.ensure_clone('public.watch_share_access', 'history.watch_share_access');

grant all on all tables in schema history to postgres, service_role;

do $$
declare
  batch uuid := gen_random_uuid();
  counts jsonb := '{}'::jsonb;
  n bigint;
begin
  insert into history.profiles
  select p.*, now(), batch from public.profiles p;
  get diagnostics n = row_count;
  counts := counts || jsonb_build_object('profiles', n);

  insert into history.rides
  select r.*, now(), batch from public.rides r;
  get diagnostics n = row_count;
  counts := counts || jsonb_build_object('rides', n);

  insert into history.track_points
  select t.*, now(), batch from public.track_points t;
  get diagnostics n = row_count;
  counts := counts || jsonb_build_object('track_points', n);

  insert into history.ride_engine_labels
  select e.*, now(), batch from public.ride_engine_labels e;
  get diagnostics n = row_count;
  counts := counts || jsonb_build_object('ride_engine_labels', n);

  insert into history.camera_events
  select c.*, now(), batch from public.camera_events c;
  get diagnostics n = row_count;
  counts := counts || jsonb_build_object('camera_events', n);

  insert into history.camera_config_snapshots
  select c.*, now(), batch from public.camera_config_snapshots c;
  get diagnostics n = row_count;
  counts := counts || jsonb_build_object('camera_config_snapshots', n);

  insert into history.rodadas
  select r.*, now(), batch from public.rodadas r;
  get diagnostics n = row_count;
  counts := counts || jsonb_build_object('rodadas', n);

  insert into history.rodada_members
  select m.*, now(), batch from public.rodada_members m;
  get diagnostics n = row_count;
  counts := counts || jsonb_build_object('rodada_members', n);

  insert into history.rodada_live_positions
  select p.*, now(), batch from public.rodada_live_positions p;
  get diagnostics n = row_count;
  counts := counts || jsonb_build_object('rodada_live_positions', n);

  insert into history.rodada_photos
  select p.*, now(), batch from public.rodada_photos p;
  get diagnostics n = row_count;
  counts := counts || jsonb_build_object('rodada_photos', n);

  insert into history.rodada_messages
  select m.*, now(), batch from public.rodada_messages m;
  get diagnostics n = row_count;
  counts := counts || jsonb_build_object('rodada_messages', n);

  insert into history.rodada_stops
  select s.*, now(), batch from public.rodada_stops s;
  get diagnostics n = row_count;
  counts := counts || jsonb_build_object('rodada_stops', n);

  insert into history.rodada_reels
  select r.*, now(), batch from public.rodada_reels r;
  get diagnostics n = row_count;
  counts := counts || jsonb_build_object('rodada_reels', n);

  insert into history.watch_sessions
  select s.*, now(), batch from public.watch_sessions s;
  get diagnostics n = row_count;
  counts := counts || jsonb_build_object('watch_sessions', n);

  insert into history.watch_positions
  select p.*, now(), batch from public.watch_positions p;
  get diagnostics n = row_count;
  counts := counts || jsonb_build_object('watch_positions', n);

  insert into history.watch_events
  select e.*, now(), batch from public.watch_events e;
  get diagnostics n = row_count;
  counts := counts || jsonb_build_object('watch_events', n);

  insert into history.watch_share_tokens
  select t.*, now(), batch from public.watch_share_tokens t;
  get diagnostics n = row_count;
  counts := counts || jsonb_build_object('watch_share_tokens', n);

  insert into history.watch_share_access
  select a.*, now(), batch from public.watch_share_access a;
  get diagnostics n = row_count;
  counts := counts || jsonb_build_object('watch_share_access', n);

  delete from public.watch_share_access;
  delete from public.watch_share_tokens;
  delete from public.watch_events;
  delete from public.watch_positions;
  delete from public.watch_sessions;

  delete from public.rodada_reels;
  delete from public.track_points;
  delete from public.rides;
  delete from public.rodada_live_positions;
  delete from public.rodada_photos;
  delete from public.rodada_messages;
  delete from public.rodada_stops;
  delete from public.rodada_members;
  delete from public.rodadas;

  delete from public.ride_engine_labels;
  delete from public.camera_events;
  delete from public.camera_config_snapshots;

  if pg_get_serial_sequence('public.track_points', 'id') is not null then
    perform setval(
      pg_get_serial_sequence('public.track_points', 'id'),
      1,
      false
    );
  end if;

  insert into history.archive_batches (id, note, counts)
  values (
    batch,
    'Re-archive + wipe live rides/rodadas/watch (phones may have re-synced after first wipe).',
    counts
  );

  raise notice 'Archive batch % counts=%', batch, counts;
end;
$$;
