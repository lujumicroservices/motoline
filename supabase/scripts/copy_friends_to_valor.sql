-- Idempotent clone: Cesar Pulido + RT DobleU rides → Valor.
-- Cesar:  124a264f-cbb4-4acb-8b81-6ae15fd4f33a
-- DobleU: 5683b7e0-1382-4d1f-8cbc-3fe810d312d4
-- Valor:  87ff1d09-86f8-4fd3-b3dc-e7a2281a61d9
-- Skips source rows that are already copies (local_id like 'copy-from-%').
-- Garage pull uses rides.local_id; Lean Lab pull uses remapped labels/events.

begin;

delete from public.rides
where user_id = '87ff1d09-86f8-4fd3-b3dc-e7a2281a61d9'
  and (local_id like 'copy-from-cesar-%' or local_id like 'copy-from-dobleu-%');

delete from public.routes
where owner_id = '87ff1d09-86f8-4fd3-b3dc-e7a2281a61d9'
  and description in ('copy-from-cesar', 'copy-from-dobleu');

delete from public.ride_engine_labels
where user_id = '87ff1d09-86f8-4fd3-b3dc-e7a2281a61d9'
  and (ride_local_id like 'copy-from-cesar-%' or ride_local_id like 'copy-from-dobleu-%');

delete from public.camera_events
where user_id = '87ff1d09-86f8-4fd3-b3dc-e7a2281a61d9'
  and (local_id like 'copy-from-cesar-%' or local_id like 'copy-from-dobleu-%');

create temporary table _src (
  user_id uuid primary key,
  slug text not null,
  label text not null
);

insert into _src (user_id, slug, label) values
  ('124a264f-cbb4-4acb-8b81-6ae15fd4f33a', 'cesar', 'Cesar'),
  ('5683b7e0-1382-4d1f-8cbc-3fe810d312d4', 'dobleu', 'DobleU');

create temporary table _route_map (
  old_id uuid primary key,
  new_id uuid not null,
  slug text not null
);

create temporary table _ride_map (
  old_id uuid primary key,
  new_id uuid not null,
  slug text not null,
  label text not null,
  old_local text not null,
  new_local text not null
);

insert into _route_map (old_id, new_id, slug)
select r.id, gen_random_uuid(), s.slug
from public.routes r
join _src s on s.user_id = r.owner_id
where coalesce(r.description, '') not like 'copy-from-%';

insert into public.routes (
  id, owner_id, name, description,
  init_lat, init_lng, end_lat, end_lng, geofence_radius_m,
  is_shared, visibility, created_at, updated_at
)
select
  m.new_id,
  '87ff1d09-86f8-4fd3-b3dc-e7a2281a61d9',
  r.name,
  'copy-from-' || m.slug,
  r.init_lat,
  r.init_lng,
  r.end_lat,
  r.end_lng,
  r.geofence_radius_m,
  false,
  'private',
  r.created_at,
  now()
from public.routes r
join _route_map m on m.old_id = r.id;

insert into _ride_map (old_id, new_id, slug, label, old_local, new_local)
select
  r.id,
  gen_random_uuid(),
  s.slug,
  s.label,
  r.local_id,
  'copy-from-' || s.slug || '-' || r.local_id
from public.rides r
join _src s on s.user_id = r.user_id
where r.local_id not like 'copy-from-%';

insert into public.rides (
  id, user_id, route_id, local_id,
  started_at, ended_at, distance_meters, point_count,
  max_speed_mps, avg_speed_mps, max_lean_left_deg, max_lean_right_deg,
  line_score, is_shared, visibility, title, created_at, updated_at,
  min_lat, max_lat, min_lng, max_lng
)
select
  m.new_id,
  '87ff1d09-86f8-4fd3-b3dc-e7a2281a61d9',
  rm.new_id,
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
  '[' || m.label || '] ' || coalesce(nullif(trim(r.title), ''), 'ride'),
  r.created_at,
  now(),
  r.min_lat,
  r.max_lat,
  r.min_lng,
  r.max_lng
from public.rides r
join _ride_map m on m.old_id = r.id
left join _route_map rm on rm.old_id = r.route_id;

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
  '87ff1d09-86f8-4fd3-b3dc-e7a2281a61d9',
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
  on l.ride_local_id in (m.old_local, m.old_local || '__lean_lab')
join _src s on s.user_id = l.user_id and s.slug = m.slug;

insert into public.camera_events (
  id, user_id, local_id, ride_local_id, event_type, payload,
  latitude, longitude, created_at, uploaded_at, category
)
select
  gen_random_uuid(),
  '87ff1d09-86f8-4fd3-b3dc-e7a2281a61d9',
  'copy-from-' || m.slug || '-' || e.local_id,
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
  on e.ride_local_id in (m.old_local, m.old_local || '__lean_lab')
join _src s on s.user_id = e.user_id and s.slug = m.slug;

commit;

select
  case
    when local_id like 'copy-from-cesar-%' then 'cesar'
    else 'dobleu'
  end as from_who,
  count(*) as rides,
  coalesce(sum(point_count), 0) as points
from public.rides
where user_id = '87ff1d09-86f8-4fd3-b3dc-e7a2281a61d9'
  and (local_id like 'copy-from-cesar-%' or local_id like 'copy-from-dobleu-%')
group by 1
order by 1;
