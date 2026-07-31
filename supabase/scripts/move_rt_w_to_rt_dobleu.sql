-- Move RT W cloud data → RT DOBLEU (ownership transfer, not duplicate).
-- RT W:      2b189d76-97a9-431c-be7e-d4847474d7b1
-- RT DOBLEU: 5683b7e0-1382-4d1f-8cbc-3fe810d312d4

begin;

-- Drop earlier duplicate copies on DOBLEU (track_points cascade via FK).
delete from public.rides
where user_id = '5683b7e0-1382-4d1f-8cbc-3fe810d312d4'
  and local_id like 'copy-from-rtw-%';

-- Drop DOBLEU duplicate routes created by the earlier copy script.
delete from public.routes
where owner_id = '5683b7e0-1382-4d1f-8cbc-3fe810d312d4'
  and id in (
    'd753702d-8c6c-44d0-a793-6a51be691b1c',
    'ee06317b-46fd-4e69-ad3e-8a41ca9ebfb1'
  );

-- Transfer routes.
update public.routes
set
  owner_id = '5683b7e0-1382-4d1f-8cbc-3fe810d312d4',
  updated_at = now()
where owner_id = '2b189d76-97a9-431c-be7e-d4847474d7b1';

-- Transfer rides (track_points stay attached to ride id).
update public.rides
set
  user_id = '5683b7e0-1382-4d1f-8cbc-3fe810d312d4',
  updated_at = now()
where user_id = '2b189d76-97a9-431c-be7e-d4847474d7b1';

-- Tag the long ride to the older loop route if still untagged.
update public.rides
set route_id = '3b3ce95d-cb98-44e2-a81f-6318b37a87eb'
where id = 'e0b7a2bc-950f-4d3b-833c-0315415011df'
  and route_id is null;

commit;
