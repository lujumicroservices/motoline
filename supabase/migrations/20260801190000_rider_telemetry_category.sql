-- Broaden camera_events into general rider troubleshooting telemetry.
-- Keep table name for compatibility; category filters event families.

alter table public.camera_events
  add column if not exists category text not null default 'camera';

create index if not exists camera_events_user_category_created_idx
  on public.camera_events (user_id, category, created_at desc);

comment on table public.camera_events is
  'Rider troubleshooting events (ride/gps/arm/sync/camera/ble/loop/app). Uploaded from devices for remote debug.';

comment on column public.camera_events.category is
  'ride | gps | arm | sync | camera | ble | loop | app | error';
