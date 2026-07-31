-- Wipe legacy loop anchors from all shared routes so every client refreshes clean.
update public.routes
set
  init_lat = null,
  init_lng = null,
  end_lat = null,
  end_lng = null,
  geofence_radius_m = 40,
  updated_at = now()
where
  init_lat is not null
  or init_lng is not null
  or end_lat is not null
  or end_lng is not null;
