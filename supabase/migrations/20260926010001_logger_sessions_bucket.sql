-- Private storage for raw logger session archives (best-effort).
insert into storage.buckets (id, name, public, file_size_limit)
values ('logger-sessions', 'logger-sessions', false, 52428800)
on conflict (id) do nothing;

drop policy if exists logger_sessions_select_own on storage.objects;
create policy logger_sessions_select_own
  on storage.objects for select
  using (
    bucket_id = 'logger-sessions'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists logger_sessions_insert_service on storage.objects;
-- Service role bypasses RLS; allow owner read only from clients.
