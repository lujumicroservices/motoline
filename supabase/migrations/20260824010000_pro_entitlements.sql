-- RiderLab Pro: no-card trial + single-use partner codes.
-- Product contract: docs/FREE_VS_PRO.md
-- Paid store periods (source = revenuecat) can be inserted later; the client
-- also ORs RevenueCat CustomerInfo when REVENUECAT_API_KEY is set.

create table if not exists public.promo_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  kind text not null default 'partner'
    check (kind = 'partner'),
  duration_days integer not null default 90
    check (duration_days > 0),
  partner_label text,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  redeemed_by uuid references public.profiles (id) on delete set null,
  redeemed_at timestamptz
);

create index if not exists promo_codes_redeemed_idx
  on public.promo_codes (redeemed_by)
  where redeemed_by is not null;

create table if not exists public.entitlement_periods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  source text not null
    check (source in ('trial', 'partner', 'revenuecat')),
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  promo_code_id uuid references public.promo_codes (id) on delete set null,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create index if not exists entitlement_periods_user_end_idx
  on public.entitlement_periods (user_id, ends_at desc);

create unique index if not exists entitlement_periods_one_trial
  on public.entitlement_periods (user_id)
  where source = 'trial';

create unique index if not exists entitlement_periods_one_partner
  on public.entitlement_periods (user_id)
  where source = 'partner';

alter table public.promo_codes enable row level security;
alter table public.entitlement_periods enable row level security;

drop policy if exists promo_codes_own_redeemed on public.promo_codes;
create policy promo_codes_own_redeemed
  on public.promo_codes
  for select
  to authenticated
  using (redeemed_by = auth.uid());

drop policy if exists entitlement_periods_own_select on public.entitlement_periods;
create policy entitlement_periods_own_select
  on public.entitlement_periods
  for select
  to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.generate_partner_pro_code()
returns text
language plpgsql
as $$
declare
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result text := 'PRO-';
  i int;
begin
  for i in 1..6 loop
    result := result || substr(chars, 1 + floor(random() * length(chars))::int, 1);
  end loop;
  return result;
end;
$$;

create or replace function public.normalize_partner_pro_code(p_code text)
returns text
language plpgsql
immutable
as $$
declare
  raw text := upper(regexp_replace(coalesce(p_code, ''), '\s+', '', 'g'));
begin
  raw := regexp_replace(raw, '[^A-Z0-9-]', '', 'g');
  if raw ~ '^PRO-[A-Z0-9]{6}$' then
    return raw;
  end if;
  if raw ~ '^[A-Z0-9]{6}$' then
    return 'PRO-' || raw;
  end if;
  return raw;
end;
$$;

create or replace function public._pro_status_payload(p_uid uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  active_source text;
  active_end timestamptz;
  trial_used boolean := false;
  partner_used boolean := false;
  days int := 0;
begin
  select true into trial_used
  from public.entitlement_periods
  where user_id = p_uid and source = 'trial'
  limit 1;
  trial_used := coalesce(trial_used, false);

  select true into partner_used
  from public.entitlement_periods
  where user_id = p_uid and source = 'partner'
  limit 1;
  partner_used := coalesce(partner_used, false);

  select e.source, e.ends_at
    into active_source, active_end
  from public.entitlement_periods e
  where e.user_id = p_uid
    and e.ends_at > now()
  order by
    case e.source
      when 'revenuecat' then 0
      when 'partner' then 1
      else 2
    end,
    e.ends_at desc
  limit 1;

  if active_end is not null then
    days := greatest(
      1,
      ceil(extract(epoch from (active_end - now())) / 86400.0)::int
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'is_pro', active_end is not null,
    'source', active_source,
    'ends_at', active_end,
    'days_left', days,
    'trial_used', trial_used,
    'partner_used', partner_used
  );
end;
$$;

create or replace function public.my_pro_status()
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    return jsonb_build_object(
      'ok', false,
      'error', 'not_authenticated',
      'is_pro', false,
      'source', null,
      'ends_at', null,
      'days_left', 0,
      'trial_used', false,
      'partner_used', false
    );
  end if;
  return public._pro_status_payload(uid);
end;
$$;

create or replace function public.start_pro_trial()
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  uid uuid := auth.uid();
  created timestamptz;
begin
  if uid is null then
    return jsonb_build_object('ok', false, 'error', 'not_authenticated');
  end if;

  insert into public.profiles (id)
  values (uid)
  on conflict (id) do nothing;

  if exists (
    select 1 from public.entitlement_periods
    where user_id = uid and source = 'trial'
  ) then
    return public._pro_status_payload(uid) || jsonb_build_object('ok', true);
  end if;

  select u.created_at into created
  from auth.users u
  where u.id = uid;

  if created is not null and created < now() - interval '90 days' then
    return public._pro_status_payload(uid) || jsonb_build_object(
      'ok', false,
      'error', 'trial_window_expired'
    );
  end if;

  insert into public.entitlement_periods (
    user_id, source, starts_at, ends_at
  ) values (
    uid, 'trial', now(), now() + interval '30 days'
  );

  return public._pro_status_payload(uid) || jsonb_build_object('ok', true);
end;
$$;

create or replace function public.redeem_partner_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  normalized text := public.normalize_partner_pro_code(p_code);
  code_id uuid;
  dur integer;
  current_end timestamptz;
  new_end timestamptz;
begin
  if uid is null then
    return jsonb_build_object('ok', false, 'error', 'not_authenticated');
  end if;

  insert into public.profiles (id)
  values (uid)
  on conflict (id) do nothing;

  if exists (
    select 1 from public.entitlement_periods
    where user_id = uid
      and source = 'revenuecat'
      and ends_at > now()
  ) then
    return jsonb_build_object('ok', false, 'error', 'already_paying');
  end if;

  if exists (
    select 1 from public.entitlement_periods
    where user_id = uid and source = 'partner'
  ) then
    return jsonb_build_object('ok', false, 'error', 'already_redeemed_partner');
  end if;

  if normalized is null or normalized !~ '^PRO-[A-Z0-9]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'invalid_code');
  end if;

  update public.promo_codes
  set redeemed_by = uid,
      redeemed_at = now()
  where code = normalized
    and redeemed_by is null
  returning id, duration_days into code_id, dur;

  if code_id is null then
    if exists (select 1 from public.promo_codes where code = normalized) then
      return jsonb_build_object('ok', false, 'error', 'code_used');
    end if;
    return jsonb_build_object('ok', false, 'error', 'invalid_code');
  end if;

  select max(ends_at) into current_end
  from public.entitlement_periods
  where user_id = uid
    and ends_at > now();

  new_end := greatest(
    coalesce(current_end, now()),
    now() + make_interval(days => coalesce(dur, 90))
  );

  insert into public.entitlement_periods (
    user_id, source, starts_at, ends_at, promo_code_id
  ) values (
    uid, 'partner', now(), new_end, code_id
  );

  return public._pro_status_payload(uid) || jsonb_build_object('ok', true);
end;
$$;

create or replace function public.staff_create_partner_code(p_label text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  new_code text;
  i int;
begin
  if uid is null then
    return jsonb_build_object('ok', false, 'error', 'not_authenticated');
  end if;
  if not exists (
    select 1 from public.staff_admins where user_id = uid
  ) then
    return jsonb_build_object('ok', false, 'error', 'not_staff');
  end if;

  for i in 1..8 loop
    new_code := public.generate_partner_pro_code();
    begin
      insert into public.promo_codes (
        code, kind, duration_days, partner_label, created_by
      ) values (
        new_code, 'partner', 90, nullif(trim(p_label), ''), uid
      );
      return jsonb_build_object('ok', true, 'code', new_code);
    exception
      when unique_violation then
        null;
    end;
  end loop;

  return jsonb_build_object('ok', false, 'error', 'code_gen_failed');
end;
$$;

revoke all on function public.my_pro_status() from public;
revoke all on function public.start_pro_trial() from public;
revoke all on function public.redeem_partner_code(text) from public;
revoke all on function public.staff_create_partner_code(text) from public;
revoke all on function public._pro_status_payload(uuid) from public;
revoke all on function public.generate_partner_pro_code() from public;
revoke all on function public.normalize_partner_pro_code(text) from public;

grant execute on function public.my_pro_status() to authenticated;
grant execute on function public.start_pro_trial() to authenticated;
grant execute on function public.redeem_partner_code(text) to authenticated;
grant execute on function public.staff_create_partner_code(text) to authenticated;
-- normalize is used by redeem (definer); not granted to clients.
