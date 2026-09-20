-- Staff export: SIMM leads + reserved partner code. Do NOT email from SQL.
-- Codes stay gated until an explicit send.

select
  l.created_at at time zone 'America/Mexico_City' as created_mx,
  l.name,
  l.platform,
  l.email,
  l.phone,
  l.source,
  l.utm,
  c.code as simm26_code,
  c.redeemed_at as code_redeemed_at
from public.event_leads l
left join public.promo_codes c on c.id = l.promo_code_id
where l.source = 'simm-2026'
order by l.created_at;

select source, hits, updated_at
from public.event_page_hits
where source = 'simm-2026';
