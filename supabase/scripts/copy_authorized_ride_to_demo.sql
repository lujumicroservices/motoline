-- Copy ONE authorized ride onto a demo booth account.
-- Edit src_ride and dest_user below. Do not copy random production users.
-- Demo phones must already be signed in as dest_user.

begin;

do $$
declare
  src_ride uuid := null;  -- paste authorized ride id
  dest_user uuid := null; -- paste booth Google account user id
  new_ride uuid := gen_random_uuid();
  old_local text;
  new_local text;
  old_user uuid;
begin
  if src_ride is null or dest_user is null then
    raise exception 'Set src_ride and dest_user UUIDs before running';
  end if;

  select r.local_id, r.user_id
    into old_local, old_user
  from public.rides r
  where r.id = src_ride;
  if old_local is null then
    raise exception 'source ride not found';
  end if;
  new_local := 'simm-demo-' || old_local;

  delete from public.ride_engine_labels
  where user_id = dest_user and ride_local_id like 'simm-demo-%';
  delete from public.camera_events
  where user_id = dest_user
    and (local_id like 'simm-demo-%' or ride_local_id like 'simm-demo-%');
  delete from public.rides
  where user_id = dest_user and local_id like 'simm-demo-%';

  insert into public.rides (
    id, user_id, route_id, local_id,
    started_at, ended_at, distance_meters, point_count,
    max_speed_mps, avg_speed_mps, max_lean_left_deg, max_lean_right_deg,
    line_score, is_shared, visibility, title, created_at, updated_at,
    min_lat, max_lat, min_lng, max_lng
  )
  select
    new_ride,
    dest_user,
    null,
    new_local,
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
    '[SIMM demo] ' || coalesce(nullif(trim(r.title), ''), 'ride'),
    r.created_at,
    now(),
    r.min_lat,
    r.max_lat,
    r.min_lng,
    r.max_lng
  from public.rides r
  where r.id = src_ride;

  insert into public.track_points (
    ride_id, recorded_at, latitude, longitude, altitude,
    speed_mps, accuracy_meters, heading, lean_degrees, pressure_hpa
  )
  select
    new_ride,
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
  where tp.ride_id = src_ride;

  insert into public.ride_engine_labels (
    id, user_id, ride_local_id, phone_mount, lean_quality, brake_feel,
    ride_context, notes, payload, labeled_at
  )
  select
    gen_random_uuid(),
    dest_user,
    case
      when l.ride_local_id = old_local || '__lean_lab' then new_local || '__lean_lab'
      else new_local
    end,
    l.phone_mount,
    l.lean_quality,
    l.brake_feel,
    l.ride_context,
    l.notes,
    case
      when l.payload ? 'ride_id'
        then jsonb_set(l.payload, '{ride_id}', to_jsonb(new_local), true)
      else l.payload
    end,
    l.labeled_at
  from public.ride_engine_labels l
  where l.user_id = old_user
    and l.ride_local_id in (old_local, old_local || '__lean_lab');
end $$;

commit;
