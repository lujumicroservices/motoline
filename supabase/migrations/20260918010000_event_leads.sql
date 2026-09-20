-- SIMM / event waitlist. Public writes go through submit-event-lead (service role).
-- Partner codes: SIMM26-XXXXXX, 90-day Pro. Attached to leads; not auto-sent.

create table if not exists public.event_leads (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  name text not null,
  platform text not null check (platform in ('android', 'ios')),
  email text,
  phone text,
  email_norm text,
  phone_digits text,
  consent_at timestamptz not null,
  source text not null default 'simm-2026',
  utm jsonb not null default '{}'::jsonb,
  promo_code_id uuid references public.promo_codes (id) on delete set null,
  check (
    (email_norm is not null and email_norm <> '')
    or (phone_digits is not null and phone_digits <> '')
  )
);

create unique index if not exists event_leads_email_norm_uidx
  on public.event_leads (email_norm)
  where email_norm is not null and email_norm <> '';

create unique index if not exists event_leads_phone_digits_uidx
  on public.event_leads (phone_digits)
  where phone_digits is not null and phone_digits <> '';

create index if not exists event_leads_source_created_idx
  on public.event_leads (source, created_at desc);

create table if not exists public.event_page_hits (
  source text primary key,
  hits bigint not null default 0,
  updated_at timestamptz not null default now()
);

insert into public.event_page_hits (source, hits)
values ('simm-2026', 0)
on conflict (source) do nothing;

create table if not exists public.event_lead_rate (
  id bigint generated always as identity primary key,
  ip_hash text not null,
  kind text not null,
  created_at timestamptz not null default now()
);

create index if not exists event_lead_rate_lookup_idx
  on public.event_lead_rate (ip_hash, kind, created_at desc);

alter table public.event_leads enable row level security;
alter table public.event_page_hits enable row level security;
alter table public.event_lead_rate enable row level security;

drop policy if exists event_leads_staff_select on public.event_leads;
create policy event_leads_staff_select
  on public.event_leads
  for select
  to authenticated
  using (exists (select 1 from public.staff_admins where user_id = auth.uid()));

drop policy if exists event_page_hits_staff_select on public.event_page_hits;
create policy event_page_hits_staff_select
  on public.event_page_hits
  for select
  to authenticated
  using (exists (select 1 from public.staff_admins where user_id = auth.uid()));

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
  if raw ~ '^SIMM26-[A-Z0-9]{6}$' then
    return raw;
  end if;
  if raw ~ '^[A-Z0-9]{6}$' then
    return 'PRO-' || raw;
  end if;
  return raw;
end;
$$;

create or replace function public.generate_simm26_partner_code()
returns text
language plpgsql
as $$
declare
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result text := 'SIMM26-';
  i int;
begin
  for i in 1..6 loop
    result := result || substr(chars, 1 + floor(random() * length(chars))::int, 1);
  end loop;
  return result;
end;
$$;

create or replace function public.mint_simm26_partner_codes(p_count integer default 200)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n int := 0;
  i int;
  new_code text;
  k int;
begin
  if p_count is null or p_count < 1 then
    return 0;
  end if;
  if p_count > 500 then
    p_count := 500;
  end if;
  for i in 1..p_count loop
    for k in 1..8 loop
      new_code := public.generate_simm26_partner_code();
      begin
        insert into public.promo_codes (
          code, kind, duration_days, partner_label
        ) values (
          new_code, 'partner', 90, 'SIMM26'
        );
        n := n + 1;
        exit;
      exception
        when unique_violation then
          null;
      end;
    end loop;
  end loop;
  return n;
end;
$$;

create or replace function public.event_bump_page_hit(p_source text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.event_page_hits (source, hits, updated_at)
  values (coalesce(nullif(trim(p_source), ''), 'simm-2026'), 1, now())
  on conflict (source) do update
    set hits = public.event_page_hits.hits + 1,
        updated_at = now();
end;
$$;

create or replace function public.submit_event_lead(
  p_name text,
  p_platform text,
  p_email text,
  p_phone text,
  p_source text,
  p_utm jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := nullif(trim(p_name), '');
  v_platform text := lower(trim(p_platform));
  v_email text := nullif(lower(trim(p_email)), '');
  v_phone text := nullif(regexp_replace(coalesce(p_phone, ''), '\D', '', 'g'), '');
  v_source text := coalesce(nullif(trim(p_source), ''), 'simm-2026');
  v_id uuid;
  v_code uuid;
begin
  if v_name is null or char_length(v_name) < 2 or char_length(v_name) > 80 then
    return jsonb_build_object('ok', false, 'error', 'name');
  end if;
  if v_platform not in ('android', 'ios') then
    return jsonb_build_object('ok', false, 'error', 'platform');
  end if;
  if v_email is not null and (
    v_email !~ '^[^\s@]+@[^\s@]+\.[^\s@]+$' or char_length(v_email) > 160
  ) then
    v_email := null;
  end if;
  if v_phone is not null and (
    char_length(v_phone) < 10 or char_length(v_phone) > 15
  ) then
    v_phone := null;
  end if;
  if v_email is null and v_phone is null then
    return jsonb_build_object('ok', false, 'error', 'contact');
  end if;

  select id into v_id
  from public.event_leads
  where (v_email is not null and email_norm = v_email)
     or (v_phone is not null and phone_digits = v_phone)
  limit 1;

  if v_id is not null then
    update public.event_leads
    set name = v_name,
        platform = v_platform,
        consent_at = now(),
        utm = coalesce(p_utm, '{}'::jsonb)
    where id = v_id;
    return jsonb_build_object('ok', true, 'duplicate', true);
  end if;

  select c.id into v_code
  from public.promo_codes c
  where c.partner_label = 'SIMM26'
    and c.redeemed_by is null
    and not exists (
      select 1 from public.event_leads l where l.promo_code_id = c.id
    )
  limit 1
  for update skip locked;

  insert into public.event_leads (
    name, platform, email, phone, email_norm, phone_digits,
    consent_at, source, utm, promo_code_id
  ) values (
    v_name, v_platform, v_email, v_phone, v_email, v_phone,
    now(), v_source, coalesce(p_utm, '{}'::jsonb), v_code
  );

  return jsonb_build_object('ok', true, 'duplicate', false);
end;
$$;

revoke all on function public.generate_simm26_partner_code() from public;
revoke all on function public.mint_simm26_partner_codes(integer) from public;
revoke all on function public.event_bump_page_hit(text) from public;
revoke all on function public.submit_event_lead(text, text, text, text, text, jsonb) from public;

grant execute on function public.mint_simm26_partner_codes(integer) to service_role;
grant execute on function public.event_bump_page_hit(text) to service_role;
grant execute on function public.submit_event_lead(text, text, text, text, text, jsonb) to service_role;

select public.mint_simm26_partner_codes(200);
