-- UGC safety for Play: report radio/photos, staff hide, account ban.

alter table public.rodada_messages
  add column if not exists hidden_at timestamptz,
  add column if not exists hidden_by uuid references auth.users (id);

alter table public.rodada_photos
  add column if not exists hidden_at timestamptz,
  add column if not exists hidden_by uuid references auth.users (id);

create table if not exists public.user_bans (
  user_id uuid primary key references auth.users (id) on delete cascade,
  banned_at timestamptz not null default now(),
  banned_by uuid not null references auth.users (id),
  reason text not null default 'other',
  notes text
);

alter table public.user_bans enable row level security;

drop policy if exists user_bans_self_select on public.user_bans;
create policy user_bans_self_select
  on public.user_bans for select
  to authenticated
  using (user_id = auth.uid());

create table if not exists public.content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users (id) on delete cascade,
  target_user_id uuid not null references auth.users (id) on delete cascade,
  rodada_id uuid not null references public.rodadas (id) on delete cascade,
  kind text not null check (kind in ('message', 'photo')),
  message_id uuid references public.rodada_messages (id) on delete set null,
  photo_id uuid references public.rodada_photos (id) on delete set null,
  reason text not null check (
    reason in ('sexual', 'hate', 'harassment', 'spam', 'other')
  ),
  details text,
  status text not null default 'open' check (
    status in ('open', 'hidden', 'dismissed', 'banned')
  ),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users (id),
  constraint content_reports_target check (
    (kind = 'message' and message_id is not null and photo_id is null)
    or (kind = 'photo' and photo_id is not null and message_id is null)
  )
);

create unique index if not exists content_reports_one_message
  on public.content_reports (reporter_id, message_id)
  where message_id is not null;

create unique index if not exists content_reports_one_photo
  on public.content_reports (reporter_id, photo_id)
  where photo_id is not null;

create index if not exists content_reports_open_idx
  on public.content_reports (status, created_at desc);

alter table public.content_reports enable row level security;

-- Members insert via RPC only. No client SELECT (staff uses definer).
drop policy if exists content_reports_no_direct on public.content_reports;

create or replace function public.is_staff_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.staff_admins where user_id = auth.uid()
  );
$$;

create or replace function public.reject_banned_ugc()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (select 1 from public.user_bans where user_id = new.user_id) then
    raise exception 'ugc_banned';
  end if;
  return new;
end;
$$;

drop trigger if exists rodada_messages_reject_banned on public.rodada_messages;
create trigger rodada_messages_reject_banned
  before insert on public.rodada_messages
  for each row execute function public.reject_banned_ugc();

drop trigger if exists rodada_photos_reject_banned on public.rodada_photos;
create trigger rodada_photos_reject_banned
  before insert on public.rodada_photos
  for each row execute function public.reject_banned_ugc();

drop trigger if exists rodada_reels_reject_banned on public.rodada_reels;
create trigger rodada_reels_reject_banned
  before insert on public.rodada_reels
  for each row execute function public.reject_banned_ugc();

-- Hide banned/hidden rows from members. Staff still uses RPCs for the queue.
drop policy if exists rodada_messages_select on public.rodada_messages;
create policy rodada_messages_select
  on public.rodada_messages for select
  using (
    public.is_rodada_member(rodada_id)
    and hidden_at is null
  );

drop policy if exists rodada_photos_select on public.rodada_photos;
create policy rodada_photos_select
  on public.rodada_photos for select
  using (
    public.is_rodada_member(rodada_id)
    and hidden_at is null
  );

create or replace function public.report_rodada_content(
  p_kind text,
  p_message_id uuid default null,
  p_photo_id uuid default null,
  p_reason text default 'other',
  p_details text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  rid uuid;
  target uuid;
begin
  if uid is null then
    return jsonb_build_object('ok', false, 'error', 'not_authenticated');
  end if;
  if exists (select 1 from public.user_bans where user_id = uid) then
    return jsonb_build_object('ok', false, 'error', 'ugc_banned');
  end if;
  if p_reason not in ('sexual', 'hate', 'harassment', 'spam', 'other') then
    return jsonb_build_object('ok', false, 'error', 'bad_reason');
  end if;

  if p_kind = 'message' then
    select m.rodada_id, m.user_id into rid, target
    from public.rodada_messages m
    where m.id = p_message_id;
  elsif p_kind = 'photo' then
    select p.rodada_id, p.user_id into rid, target
    from public.rodada_photos p
    where p.id = p_photo_id;
  else
    return jsonb_build_object('ok', false, 'error', 'bad_kind');
  end if;

  if rid is null then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if target = uid then
    return jsonb_build_object('ok', false, 'error', 'own_content');
  end if;
  if not public.is_rodada_member(rid) then
    return jsonb_build_object('ok', false, 'error', 'not_member');
  end if;

  insert into public.content_reports (
    reporter_id, target_user_id, rodada_id, kind,
    message_id, photo_id, reason, details
  ) values (
    uid, target, rid, p_kind,
    case when p_kind = 'message' then p_message_id end,
    case when p_kind = 'photo' then p_photo_id end,
    p_reason, nullif(trim(p_details), '')
  )
  on conflict do nothing;

  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.staff_list_content_reports(
  p_status text default 'open'
)
returns table (
  id uuid,
  kind text,
  reason text,
  details text,
  status text,
  created_at timestamptz,
  reporter_id uuid,
  reporter_name text,
  target_user_id uuid,
  target_name text,
  target_banned boolean,
  rodada_id uuid,
  message_id uuid,
  photo_id uuid,
  message_body text,
  photo_path text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_staff_admin() then
    raise exception 'not_staff';
  end if;

  return query
  select
    r.id,
    r.kind,
    r.reason,
    r.details,
    r.status,
    r.created_at,
    r.reporter_id,
    coalesce(rp.display_name, '') as reporter_name,
    r.target_user_id,
    coalesce(tp.display_name, '') as target_name,
    exists (select 1 from public.user_bans b where b.user_id = r.target_user_id)
      as target_banned,
    r.rodada_id,
    r.message_id,
    r.photo_id,
    m.body as message_body,
    ph.storage_path as photo_path
  from public.content_reports r
  left join public.profiles rp on rp.id = r.reporter_id
  left join public.profiles tp on tp.id = r.target_user_id
  left join public.rodada_messages m on m.id = r.message_id
  left join public.rodada_photos ph on ph.id = r.photo_id
  where p_status is null or p_status = 'all' or r.status = p_status
  order by r.created_at desc
  limit 80;
end;
$$;

create or replace function public.staff_resolve_report(
  p_report_id uuid,
  p_action text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  rec public.content_reports%rowtype;
begin
  if not public.is_staff_admin() then
    return jsonb_build_object('ok', false, 'error', 'not_staff');
  end if;
  if p_action not in ('hide', 'dismiss', 'ban') then
    return jsonb_build_object('ok', false, 'error', 'bad_action');
  end if;

  select * into rec from public.content_reports where id = p_report_id;
  if rec.id is null then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;

  if p_action = 'dismiss' then
    update public.content_reports
    set status = 'dismissed', reviewed_at = now(), reviewed_by = uid
    where id = rec.id;
    return jsonb_build_object('ok', true, 'status', 'dismissed');
  end if;

  if rec.kind = 'message' and rec.message_id is not null then
    update public.rodada_messages
    set hidden_at = now(), hidden_by = uid
    where id = rec.message_id and hidden_at is null;
  elsif rec.kind = 'photo' and rec.photo_id is not null then
    update public.rodada_photos
    set hidden_at = now(), hidden_by = uid
    where id = rec.photo_id and hidden_at is null;
  end if;

  if p_action = 'ban' then
    insert into public.user_bans (user_id, banned_by, reason, notes)
    values (rec.target_user_id, uid, rec.reason, rec.details)
    on conflict (user_id) do update
      set banned_at = now(), banned_by = excluded.banned_by,
          reason = excluded.reason;
    update public.content_reports
    set status = 'banned', reviewed_at = now(), reviewed_by = uid
    where target_user_id = rec.target_user_id and status = 'open';
    return jsonb_build_object('ok', true, 'status', 'banned');
  end if;

  update public.content_reports
  set status = 'hidden', reviewed_at = now(), reviewed_by = uid
  where id = rec.id;
  return jsonb_build_object('ok', true, 'status', 'hidden');
end;
$$;

create or replace function public.staff_unban_user(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_staff_admin() then
    return jsonb_build_object('ok', false, 'error', 'not_staff');
  end if;
  delete from public.user_bans where user_id = p_user_id;
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.is_staff_admin() from public;
revoke all on function public.report_rodada_content(text, uuid, uuid, text, text) from public;
revoke all on function public.staff_list_content_reports(text) from public;
revoke all on function public.staff_resolve_report(uuid, text) from public;
revoke all on function public.staff_unban_user(uuid) from public;

grant execute on function public.is_staff_admin() to authenticated;
grant execute on function public.report_rodada_content(text, uuid, uuid, text, text) to authenticated;
grant execute on function public.staff_list_content_reports(text) to authenticated;
grant execute on function public.staff_resolve_report(uuid, text) to authenticated;
grant execute on function public.staff_unban_user(uuid) to authenticated;

-- Staff must review reported photos even if they are not in that rodada.
drop policy if exists rodada_photos_storage_staff_select on storage.objects;
create policy rodada_photos_storage_staff_select
  on storage.objects for select
  using (
    bucket_id = 'rodada-photos'
    and public.is_staff_admin()
  );
