-- Real friendships + 3-level share visibility (private / friends / public).

-- ---------------------------------------------------------------------------
-- Friendships
-- ---------------------------------------------------------------------------

create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles (id) on delete cascade,
  addressee_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (requester_id <> addressee_id)
);

create unique index if not exists friendships_pair_uidx
  on public.friendships (
    least(requester_id, addressee_id),
    greatest(requester_id, addressee_id)
  );

create index if not exists friendships_requester_idx
  on public.friendships (requester_id, status);
create index if not exists friendships_addressee_idx
  on public.friendships (addressee_id, status);

create or replace function public.are_friends(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.friendships f
    where f.status = 'accepted'
      and (
        (f.requester_id = a and f.addressee_id = b)
        or (f.requester_id = b and f.addressee_id = a)
      )
  );
$$;

grant execute on function public.are_friends(uuid, uuid) to authenticated;

alter table public.friendships enable row level security;

drop policy if exists friendships_select on public.friendships;
create policy friendships_select
  on public.friendships for select
  using (requester_id = auth.uid() or addressee_id = auth.uid());

drop policy if exists friendships_insert on public.friendships;
create policy friendships_insert
  on public.friendships for insert
  with check (requester_id = auth.uid() and status = 'pending');

drop policy if exists friendships_update on public.friendships;
create policy friendships_update
  on public.friendships for update
  using (requester_id = auth.uid() or addressee_id = auth.uid())
  with check (requester_id = auth.uid() or addressee_id = auth.uid());

drop policy if exists friendships_delete on public.friendships;
create policy friendships_delete
  on public.friendships for delete
  using (requester_id = auth.uid() or addressee_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Visibility on rides + routes
-- ---------------------------------------------------------------------------

alter table public.rides
  add column if not exists visibility text;

alter table public.routes
  add column if not exists visibility text;

update public.rides
set visibility = case when is_shared then 'public' else 'private' end
where visibility is null;

update public.routes
set visibility = case when is_shared then 'public' else 'private' end
where visibility is null;

alter table public.rides
  alter column visibility set default 'friends';
alter table public.routes
  alter column visibility set default 'friends';

update public.rides set visibility = 'friends' where visibility is null;
update public.routes set visibility = 'friends' where visibility is null;

alter table public.rides alter column visibility set not null;
alter table public.routes alter column visibility set not null;

alter table public.rides drop constraint if exists rides_visibility_check;
alter table public.rides
  add constraint rides_visibility_check
  check (visibility in ('private', 'friends', 'public'));

alter table public.routes drop constraint if exists routes_visibility_check;
alter table public.routes
  add constraint routes_visibility_check
  check (visibility in ('private', 'friends', 'public'));

-- Keep is_shared in sync for legacy readers (true only when public).
create or replace function public.sync_is_shared_from_visibility()
returns trigger
language plpgsql
as $$
begin
  new.is_shared := (new.visibility = 'public');
  return new;
end;
$$;

drop trigger if exists rides_visibility_trg on public.rides;
create trigger rides_visibility_trg
  before insert or update of visibility on public.rides
  for each row execute function public.sync_is_shared_from_visibility();

drop trigger if exists routes_visibility_trg on public.routes;
create trigger routes_visibility_trg
  before insert or update of visibility on public.routes
  for each row execute function public.sync_is_shared_from_visibility();

-- Force one-time sync of is_shared from visibility
update public.rides set is_shared = (visibility = 'public');
update public.routes set is_shared = (visibility = 'public');

-- ---------------------------------------------------------------------------
-- RLS: rides / routes / track_points with visibility
-- ---------------------------------------------------------------------------

drop policy if exists "rides_select_own_or_shared" on public.rides;
drop policy if exists rides_select_own_or_shared on public.rides;
drop policy if exists rides_select_rodada_member on public.rides;

create policy rides_select_visibility
  on public.rides for select
  using (
    user_id = auth.uid()
    or visibility = 'public'
    or (
      visibility = 'friends'
      and public.are_friends(user_id, auth.uid())
    )
    or (
      rodada_id is not null
      and public.is_rodada_member(rodada_id)
      and exists (
        select 1 from public.rodada_members m
        where m.rodada_id = rides.rodada_id
          and m.user_id = rides.user_id
          and m.share_track = true
      )
    )
  );

drop policy if exists "routes_select_own_or_shared" on public.routes;
drop policy if exists routes_select_own_or_shared on public.routes;

create policy routes_select_visibility
  on public.routes for select
  using (
    owner_id = auth.uid()
    or visibility = 'public'
    or (
      visibility = 'friends'
      and public.are_friends(owner_id, auth.uid())
    )
  );

drop policy if exists "track_points_select_via_ride" on public.track_points;
drop policy if exists track_points_select_via_ride on public.track_points;
drop policy if exists track_points_select_rodada on public.track_points;

create policy track_points_select_visibility
  on public.track_points for select
  using (
    exists (
      select 1 from public.rides r
      where r.id = track_points.ride_id
        and (
          r.user_id = auth.uid()
          or r.visibility = 'public'
          or (
            r.visibility = 'friends'
            and public.are_friends(r.user_id, auth.uid())
          )
          or (
            r.rodada_id is not null
            and public.is_rodada_member(r.rodada_id)
            and exists (
              select 1 from public.rodada_members m
              where m.rodada_id = r.rodada_id
                and m.user_id = r.user_id
                and m.share_track = true
            )
          )
        )
    )
  );

-- Overlapping peers: public rides OR friends-visibility with friendship
create or replace function public.rides_overlapping(
  p_min_lat double precision,
  p_max_lat double precision,
  p_min_lng double precision,
  p_max_lng double precision,
  p_exclude_ride_id uuid default null,
  p_pad_deg double precision default 0.0025
)
returns setof public.rides
language sql
stable
security invoker
as $$
  select r.*
  from public.rides r
  where r.user_id is distinct from auth.uid()
    and (p_exclude_ride_id is null or r.id is distinct from p_exclude_ride_id)
    and r.min_lat is not null
    and r.max_lat is not null
    and r.min_lng is not null
    and r.max_lng is not null
    and (
      r.visibility = 'public'
      or (
        r.visibility = 'friends'
        and public.are_friends(r.user_id, auth.uid())
      )
    )
    and r.min_lat <= (p_max_lat + p_pad_deg)
    and r.max_lat >= (p_min_lat - p_pad_deg)
    and r.min_lng <= (p_max_lng + p_pad_deg)
    and r.max_lng >= (p_min_lng - p_pad_deg)
  order by r.started_at desc;
$$;

-- Search riders by display name (for friend requests)
create or replace function public.search_riders(p_query text, p_limit int default 20)
returns table (id uuid, display_name text, created_at timestamptz)
language sql
stable
security invoker
set search_path = public
as $$
  select p.id, p.display_name, p.created_at
  from public.profiles p
  where p.id is distinct from auth.uid()
    and p.display_name is not null
    and length(trim(p.display_name)) > 0
    and (
      p.display_name ilike '%' || trim(p_query) || '%'
      or p.id::text ilike trim(p_query) || '%'
    )
  order by p.display_name
  limit greatest(1, least(coalesce(p_limit, 20), 40));
$$;

grant execute on function public.search_riders(text, int) to authenticated;
