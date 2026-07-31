-- Copy cloud data from RT W → RT DOBLEU (duplicate; source kept).
-- RT W:      2b189d76-97a9-431c-be7e-d4847474d7b1
-- RT DOBLEU: 5683b7e0-1382-4d1f-8cbc-3fe810d312d4

begin;

create temporary table _route_map (
  old_id uuid primary key,
  new_id uuid not null
);

create temporary table _ride_map (
  old_id uuid primary key,
  new_id uuid not null
);

insert into _route_map (old_id, new_id)
select id, gen_random_uuid()
from public.routes
where owner_id = '2b189d76-97a9-431c-be7e-d4847474d7b1';

insert into public.routes (
  id, owner_id, name, description,
  init_lat, init_lng, end_lat, end_lng, geofence_radius_m,
  is_shared, created_at, updated_at
)
select
  m.new_id,
  '5683b7e0-1382-4d1f-8cbc-3fe810d312d4',
  r.name,
  r.description,
  r.init_lat,
  r.init_lng,
  r.end_lat,
  r.end_lng,
  r.geofence_radius_m,
  r.is_shared,
  r.created_at,
  now()
from public.routes r
join _route_map m on m.old_id = r.id;

insert into _ride_map (old_id, new_id)
select id, gen_random_uuid()
from public.rides
where user_id = '2b189d76-97a9-431c-be7e-d4847474d7b1';

insert into public.rides (
  id,
  user_id,
  route_id,
  local_id,
  started_at,
  ended_at,
  distance_meters,
  point_count,
  max_speed_mps,
  avg_speed_mps,
  max_lean_left_deg,
  max_lean_right_deg,
  line_score,
  is_shared,
  created_at,
  updated_at,
  min_lat,
  max_lat,
  min_lng,
  max_lng
)
select
  m.new_id,
  '5683b7e0-1382-4d1f-8cbc-3fe810d312d4',
  rm.new_id,
  'copy-from-rtw-' || r.local_id,
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
  ride_id,
  recorded_at,
  latitude,
  longitude,
  altitude,
  speed_mps,
  accuracy_meters,
  heading,
  lean_degrees
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
  tp.lean_degrees
from public.track_points tp
join _ride_map m on m.old_id = tp.ride_id;

commit;
