-- Default 30-day Pro trial on first signed-in status check.
-- Drop the 90-day signup window so existing testers still get the trial.
-- One trial row per account (entitlement_periods_one_trial).

create or replace function public.start_pro_trial()
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  uid uuid := auth.uid();
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

  insert into public.entitlement_periods (
    user_id, source, starts_at, ends_at
  ) values (
    uid, 'trial', now(), now() + interval '30 days'
  );

  return public._pro_status_payload(uid) || jsonb_build_object('ok', true);
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
  perform public.start_pro_trial();
  return public._pro_status_payload(uid);
end;
$$;
