-- Ensure RT DOBLEU ride metrics match track_points (cloud persistence).
-- RT DOBLEU: 5683b7e0-1382-4d1f-8cbc-3fe810d312d4

begin;

update public.rides r
set
  point_count = sub.pts,
  max_speed_mps = coalesce(r.max_speed_mps, sub.max_spd),
  avg_speed_mps = coalesce(
    r.avg_speed_mps,
    case when sub.pts > 0 then sub.sum_spd / sub.pts else null end
  ),
  max_lean_left_deg = coalesce(r.max_lean_left_deg, sub.lean_l),
  max_lean_right_deg = coalesce(r.max_lean_right_deg, sub.lean_r),
  min_lat = coalesce(r.min_lat, sub.min_lat),
  max_lat = coalesce(r.max_lat, sub.max_lat),
  min_lng = coalesce(r.min_lng, sub.min_lng),
  max_lng = coalesce(r.max_lng, sub.max_lng),
  updated_at = now()
from (
  select
    tp.ride_id,
    count(*)::int as pts,
    max(tp.speed_mps) as max_spd,
    sum(coalesce(tp.speed_mps, 0)) as sum_spd,
    max(case when tp.lean_degrees < 0 then abs(tp.lean_degrees) else 0 end) as lean_l,
    max(case when tp.lean_degrees > 0 then tp.lean_degrees else 0 end) as lean_r,
    min(tp.latitude) as min_lat,
    max(tp.latitude) as max_lat,
    min(tp.longitude) as min_lng,
    max(tp.longitude) as max_lng
  from public.track_points tp
  join public.rides rr on rr.id = tp.ride_id
  where rr.user_id = '5683b7e0-1382-4d1f-8cbc-3fe810d312d4'
  group by tp.ride_id
) sub
where r.id = sub.ride_id
  and r.user_id = '5683b7e0-1382-4d1f-8cbc-3fe810d312d4';

-- Keep long ride tagged to the older loop route when untagged.
update public.rides
set route_id = '3b3ce95d-cb98-44e2-a81f-6318b37a87eb',
    updated_at = now()
where id = 'e0b7a2bc-950f-4d3b-833c-0315415011df'
  and user_id = '5683b7e0-1382-4d1f-8cbc-3fe810d312d4'
  and route_id is null;

-- Confirm profile alias.
update public.profiles
set display_name = 'RT DOBLEU',
    updated_at = now()
where id = '5683b7e0-1382-4d1f-8cbc-3fe810d312d4';

commit;
