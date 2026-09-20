-- Extra SIMM26 90-day Pro codes (idempotent: just mints more unused rows).
-- Apply with service role / SQL editor after the event_leads migration.

select public.mint_simm26_partner_codes(200) as minted;
