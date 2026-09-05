-- Per-rodada member prefs: auto-arm when host starts, auto family watch.
-- share_live already covers sharing GPS with the pack while the rodada is live.

alter table public.rodada_members
  add column if not exists auto_arm_on_start boolean not null default false,
  add column if not exists auto_share_family boolean not null default false;
