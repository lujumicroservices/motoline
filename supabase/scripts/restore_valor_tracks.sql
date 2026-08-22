-- Restore Valor copy-from-* GPS from Cesar / DobleU originals.
-- Valor Settings sync uploaded a truncated phone track and overwrote the copies.

begin;

create temporary table _restore (
  valor_ride uuid primary key,
  source_ride uuid not null
);

insert into _restore (valor_ride, source_ride)
select v.id, s.id
from public.rides v
join public.rides s
  on s.local_id = regexp_replace(v.local_id, '^copy-from-(cesar|dobleu)-', '')
 and s.user_id in (
   '124a264f-cbb4-4acb-8b81-6ae15fd4f33a',
   '5683b7e0-1382-4d1f-8cbc-3fe810d312d4'
 )
where v.user_id = '87ff1d09-86f8-4fd3-b3dc-e7a2281a61d9'
  and v.local_id like 'copy-from-%';

delete from public.track_points tp
using _restore r
where tp.ride_id = r.valor_ride;

insert into public.track_points (
  ride_id, recorded_at, latitude, longitude, altitude,
  speed_mps, accuracy_meters, heading, lean_degrees, pressure_hpa
)
select
  r.valor_ride,
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
join _restore r on r.source_ride = tp.ride_id;

update public.rides v
set
  point_count = sub.n,
  distance_meters = s.distance_meters,
  updated_at = now()
from _restore r
join public.rides s on s.id = r.source_ride
join (
  select ride_id, count(*)::int as n
  from public.track_points
  group by ride_id
) sub on sub.ride_id = r.valor_ride
where v.id = r.valor_ride;

commit;

select
  v.title,
  v.point_count,
  round(v.distance_meters::numeric, 0) as distance_m,
  (select count(*) from track_points tp where tp.ride_id = v.id) as tp_count
from rides v
where v.user_id = '87ff1d09-86f8-4fd3-b3dc-e7a2281a61d9'
order by v.started_at;
