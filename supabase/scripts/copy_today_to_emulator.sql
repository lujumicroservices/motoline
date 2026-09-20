-- Copy today's Mexico-City rides onto the emulator account.
-- Dest: a9fb7d65-f80f-4bbb-820a-fa88f4d7b2e5  (lujumicroservices@gmail.com)
-- Idempotent for local_id copy-today-<source_local_id>.

begin;

delete from public.ride_engine_labels
where user_id = 'a9fb7d65-f80f-4bbb-820a-fa88f4d7b2e5'
  and ride_local_id like 'copy-today-%';

delete from public.camera_events
where user_id = 'a9fb7d65-f80f-4bbb-820a-fa88f4d7b2e5'
  and (local_id like 'copy-today-%' or ride_local_id like 'copy-today-%');

delete from public.rides
where user_id = 'a9fb7d65-f80f-4bbb-820a-fa88f4d7b2e5'
  and local_id like 'copy-today-%';

create temporary table _ride_map (
  old_id uuid primary key,
  new_id uuid not null,
  old_user uuid not null,
  old_local text not null,
  new_local text not null,
  rider_name text not null
);

insert into _ride_map (old_id, new_id, old_user, old_local, new_local, rider_name)
select
  r.id,
  gen_random_uuid(),
  r.user_id,
  r.local_id,
  'copy-today-' || r.local_id,
  coalesce(nullif(trim(p.display_name), ''), 'rider')
from public.rides r
join public.profiles p on p.id = r.user_id
where (r.started_at at time zone 'America/Mexico_City')::date
        = timezone('America/Mexico_City', now())::date
  and r.user_id <> 'a9fb7d65-f80f-4bbb-820a-fa88f4d7b2e5'
  and coalesce(r.local_id, '') not like 'copy-from-%'
  and coalesce(r.local_id, '') not like 'copy-today-%';

insert into public.rides (
  id, user_id, route_id, local_id,
  started_at, ended_at, distance_meters, point_count,
  max_speed_mps, avg_speed_mps, max_lean_left_deg, max_lean_right_deg,
  line_score, is_shared, visibility, title, created_at, updated_at,
  min_lat, max_lat, min_lng, max_lng
)
select
  m.new_id,
  'a9fb7d65-f80f-4bbb-820a-fa88f4d7b2e5',
  null,
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
  false,
  'private',
  '[' || m.rider_name || '] ' || coalesce(
    nullif(trim(r.title), ''),
    to_char(r.started_at at time zone 'America/Mexico_City', 'DD Mon HH24:MI')
  ),
  r.created_at,
  now(),
  r.min_lat,
  r.max_lat,
  r.min_lng,
  r.max_lng
from public.rides r
join _ride_map m on m.old_id = r.id;

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
join _ride_map m on m.old_id = tp.ride_id;

insert into public.ride_engine_labels (
  id, user_id, ride_local_id, phone_mount, lean_quality, brake_feel,
  ride_context, notes, payload, labeled_at
)
select
  gen_random_uuid(),
  'a9fb7d65-f80f-4bbb-820a-fa88f4d7b2e5',
  case
    when l.ride_local_id = m.old_local || '__lean_lab' then m.new_local || '__lean_lab'
    else m.new_local
  end,
  l.phone_mount,
  l.lean_quality,
  l.brake_feel,
  l.ride_context,
  l.notes,
  case
    when l.payload ? 'ride_id'
      then jsonb_set(l.payload, '{ride_id}', to_jsonb(m.new_local), true)
    else l.payload
  end,
  l.labeled_at
from public.ride_engine_labels l
join _ride_map m
  on l.user_id = m.old_user
 and l.ride_local_id in (m.old_local, m.old_local || '__lean_lab');

insert into public.camera_events (
  id, user_id, local_id, ride_local_id, event_type, payload,
  latitude, longitude, created_at, uploaded_at, category
)
select
  gen_random_uuid(),
  'a9fb7d65-f80f-4bbb-820a-fa88f4d7b2e5',
  'copy-today-' || e.local_id,
  case
    when e.ride_local_id = m.old_local || '__lean_lab' then m.new_local || '__lean_lab'
    when e.ride_local_id = m.old_local then m.new_local
    else e.ride_local_id
  end,
  e.event_type,
  case
    when e.payload ? 'ride_id'
      then jsonb_set(e.payload, '{ride_id}', to_jsonb(m.new_local), true)
    else e.payload
  end,
  e.latitude,
  e.longitude,
  e.created_at,
  now(),
  e.category
from public.camera_events e
join _ride_map m
  on e.user_id = m.old_user
 and e.ride_local_id in (m.old_local, m.old_local || '__lean_lab');

commit;

select
  src_p.display_name as rider_name,
  src.user_id::text as source_user_id,
  src.local_id as source_local_id,
  src.id::text as source_ride_id,
  r.local_id as dest_local_id,
  r.id::text as dest_ride_id,
  r.title,
  to_char(r.started_at at time zone 'America/Mexico_City', 'YYYY-MM-DD HH24:MI') as started_mx,
  round((r.distance_meters / 1000.0)::numeric, 2) as km,
  r.point_count,
  (select count(*) from public.track_points tp where tp.ride_id = r.id) as tp_copied
from public.rides r
join public.rides src
  on src.local_id = substring(r.local_id from 12)
 and src.local_id not like 'copy-%'
join public.profiles src_p on src_p.id = src.user_id
where r.user_id = 'a9fb7d65-f80f-4bbb-820a-fa88f4d7b2e5'
  and r.local_id like 'copy-today-%'
  and (r.started_at at time zone 'America/Mexico_City')::date
        = timezone('America/Mexico_City', now())::date
order by r.started_at;
