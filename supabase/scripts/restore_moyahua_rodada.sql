-- Restore "Moyahua Oxxo" after the 2026-08-21 03:22 UTC re-archive wipe,
-- then attach Juan + Valor as riders with linked tracks (share_track).
--
-- Archive batch: 3799bc88-5679-43b8-8612-c5e2aa0c4cb2
-- Rodada:        7d88f2ff-b454-4dd1-b1d1-a3fdc99c796f
-- Juan:          7b6b3eb1-4887-42de-b204-4b67f7c41d02  (already a member in history)
-- Valor:         87ff1d09-86f8-4fd3-b3dc-e7a2281a61d9

begin;

create or replace function pg_temp.restore_table(
  p_table text,
  p_batch uuid,
  p_extra_where text default 'true'
)
returns bigint
language plpgsql
as $$
declare
  cols text;
  sql text;
  n bigint;
begin
  select string_agg(quote_ident(p.column_name), ', ' order by p.ordinal_position)
  into cols
  from information_schema.columns p
  join information_schema.columns h
    on h.table_schema = 'history'
   and h.table_name = p.table_name
   and h.column_name = p.column_name
  where p.table_schema = 'public'
    and p.table_name = p_table
    and p.is_identity = 'NO';

  if cols is null then
    raise exception 'No overlapping columns for %', p_table;
  end if;

  sql := format(
    'insert into public.%I (%s)
     select %s from history.%I
     where archive_batch_id = %L
       and (%s)
     on conflict do nothing',
    p_table, cols, cols, p_table, p_batch, p_extra_where
  );
  execute sql;
  get diagnostics n = row_count;
  return n;
end;
$$;

-- Rodada first (members trigger adds host).
select pg_temp.restore_table(
  'rodadas',
  '3799bc88-5679-43b8-8612-c5e2aa0c4cb2',
  'id = ''7d88f2ff-b454-4dd1-b1d1-a3fdc99c796f'''
);

select pg_temp.restore_table(
  'rodada_members',
  '3799bc88-5679-43b8-8612-c5e2aa0c4cb2'
);

-- Host row is inserted by trigger with share_track=false; overlay history flags.
update public.rodada_members m
set
  share_live = h.share_live,
  share_track = h.share_track,
  presence = h.presence,
  rsvp = h.rsvp,
  role = h.role,
  updated_at = now()
from history.rodada_members h
where h.archive_batch_id = '3799bc88-5679-43b8-8612-c5e2aa0c4cb2'
  and h.rodada_id = m.rodada_id
  and h.user_id = m.user_id;

-- Day's rides + GPS (FK: rides.rodada_id needs the rodada).
select pg_temp.restore_table(
  'rides',
  '3799bc88-5679-43b8-8612-c5e2aa0c4cb2'
);

select pg_temp.restore_table(
  'track_points',
  '3799bc88-5679-43b8-8612-c5e2aa0c4cb2'
);

select setval(
  pg_get_serial_sequence('public.track_points', 'id'),
  greatest(coalesce((select max(id) from public.track_points), 1), 1),
  true
);

select pg_temp.restore_table(
  'rodada_live_positions',
  '3799bc88-5679-43b8-8612-c5e2aa0c4cb2'
);

select pg_temp.restore_table(
  'rodada_photos',
  '3799bc88-5679-43b8-8612-c5e2aa0c4cb2'
);

select pg_temp.restore_table(
  'rodada_messages',
  '3799bc88-5679-43b8-8612-c5e2aa0c4cb2'
);

select pg_temp.restore_table(
  'rodada_stops',
  '3799bc88-5679-43b8-8612-c5e2aa0c4cb2'
);

select pg_temp.restore_table(
  'rodada_reels',
  '3799bc88-5679-43b8-8612-c5e2aa0c4cb2'
);

select pg_temp.restore_table(
  'ride_engine_labels',
  '3799bc88-5679-43b8-8612-c5e2aa0c4cb2'
);

-- Valor as rider (Juan already restored from history).
insert into public.rodada_members (
  rodada_id, user_id, role, rsvp,
  share_live, share_track, presence, joined_at, updated_at
) values (
  '7d88f2ff-b454-4dd1-b1d1-a3fdc99c796f',
  '87ff1d09-86f8-4fd3-b3dc-e7a2281a61d9',
  'rider',
  'going',
  true,
  true,
  'offline',
  '2026-08-20 15:37:40+00',
  now()
)
on conflict (rodada_id, user_id) do update
set rsvp = 'going',
    share_live = true,
    share_track = true,
    updated_at = now();

-- Make sure Juan looks like he rode (history already had share flags).
update public.rodada_members
set rsvp = 'going',
    share_live = true,
    share_track = true,
    updated_at = now()
where rodada_id = '7d88f2ff-b454-4dd1-b1d1-a3fdc99c796f'
  and user_id = '7b6b3eb1-4887-42de-b204-4b67f7c41d02';

-- Link Valor's existing copies of the four rodada rides.
update public.rides
set rodada_id = '7d88f2ff-b454-4dd1-b1d1-a3fdc99c796f',
    updated_at = now()
where user_id = '87ff1d09-86f8-4fd3-b3dc-e7a2281a61d9'
  and local_id in (
    'copy-from-cesar-bbdda184-869b-4ca3-9ea0-d3d33dd4a417',
    'copy-from-cesar-81e8634d-b6f7-46d6-8707-ee113d68d617',
    'copy-from-dobleu-17121da9-e2c5-4bce-8c7f-4bae04c7cb0e',
    'copy-from-dobleu-57b285eb-bcea-4253-93c2-ecba478d80d4'
  );

-- Clone those same four rides onto Juan (he had membership, no Moyahua GPS).
create temporary table _juan_ride_map (
  old_id uuid primary key,
  new_id uuid not null default gen_random_uuid(),
  new_local text not null
);

insert into _juan_ride_map (old_id, new_local)
select r.id, 'copy-juan-' || r.local_id
from public.rides r
where r.id in (
  '339dcc96-9472-45dd-823f-95cbc9de955f',
  '5bed44f5-eaf9-48de-9725-54fb5c7ff7f7',
  'ad6fdde4-36df-4ed2-96db-9a48ae08ca7b',
  '0f5d4845-58a7-44cb-9086-57ed3685263e'
)
on conflict do nothing;

insert into public.rides (
  id, user_id, route_id, local_id,
  started_at, ended_at, distance_meters, point_count,
  max_speed_mps, avg_speed_mps, max_lean_left_deg, max_lean_right_deg,
  line_score, is_shared, visibility, title, created_at, updated_at,
  min_lat, max_lat, min_lng, max_lng, rodada_id
)
select
  m.new_id,
  '7b6b3eb1-4887-42de-b204-4b67f7c41d02',
  r.route_id,
  m.new_local,
  r.started_at,
  r.ended_at,
  r.distance_meters,
  r.point_count,
  r.max_speed_mps,
  r.avg_speed_mps,
  r.max_lean_left_deg,
  r.max_lean_right_deg,
  r.line_score,
  r.is_shared,
  r.visibility,
  r.title,
  r.created_at,
  now(),
  r.min_lat,
  r.max_lat,
  r.min_lng,
  r.max_lng,
  '7d88f2ff-b454-4dd1-b1d1-a3fdc99c796f'
from public.rides r
join _juan_ride_map m on m.old_id = r.id
on conflict (user_id, local_id) do nothing;

insert into public.track_points (
  ride_id, recorded_at, latitude, longitude, altitude,
  speed_mps, accuracy_meters, heading, lean_degrees, pressure_hpa
)
select
  m.new_id,
  tp.recorded_at,
  tp.latitude,
  tp.longitude,
  tp.altitude,
  tp.speed_mps,
  tp.accuracy_meters,
  tp.heading,
  tp.lean_degrees,
  tp.pressure_hpa
from public.track_points tp
join _juan_ride_map m on m.old_id = tp.ride_id
where not exists (
  select 1
  from public.track_points existing
  where existing.ride_id = m.new_id
  limit 1
);

commit;

select
  r.title,
  r.status,
  r.invite_code,
  (select count(*) from public.rodada_members m where m.rodada_id = r.id) as members,
  (select count(*) from public.rides x where x.rodada_id = r.id) as linked_rides,
  (select count(*) from public.rodada_photos p where p.rodada_id = r.id) as photos,
  (select count(*) from public.rodada_reels e where e.rodada_id = r.id) as reels
from public.rodadas r
where r.id = '7d88f2ff-b454-4dd1-b1d1-a3fdc99c796f';
