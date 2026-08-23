-- Staff-only impersonation (support). Service role writes audit; clients
-- may only see whether *they* are staff.

create table if not exists public.staff_admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.staff_admins enable row level security;

drop policy if exists staff_admins_self_select on public.staff_admins;
create policy staff_admins_self_select
  on public.staff_admins
  for select
  to authenticated
  using (user_id = auth.uid());

create table if not exists public.impersonation_audit (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references auth.users (id) on delete cascade,
  target_id uuid not null references auth.users (id) on delete cascade,
  started_at timestamptz not null default now(),
  client_info text
);

alter table public.impersonation_audit enable row level security;

-- No client policies: only service role (edge function) reads/writes.

insert into public.staff_admins (user_id)
select id
from auth.users
where id = '7b6b3eb1-4887-42de-b204-4b67f7c41d02'
on conflict (user_id) do nothing;

create or replace function public.staff_search_riders(q text)
returns table (
  id uuid,
  display_name text,
  email text
)
language sql
security definer
set search_path = public, auth
as $$
  select
    p.id,
    p.display_name,
    u.email::text
  from public.profiles p
  join auth.users u on u.id = p.id
  where length(trim(q)) >= 2
    and (
      p.id::text = trim(q)
      or coalesce(p.display_name, '') ilike '%' || trim(q) || '%'
      or coalesce(u.email, '') ilike '%' || trim(q) || '%'
    )
  order by p.display_name nulls last
  limit 25;
$$;

revoke all on function public.staff_search_riders(text) from public;
revoke all on function public.staff_search_riders(text) from anon;
revoke all on function public.staff_search_riders(text) from authenticated;
grant execute on function public.staff_search_riders(text) to service_role;
