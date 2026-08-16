# Family Watch (círculo + link web)

## Apply DB

```bash
supabase db push
# or run supabase/migrations/20260815220000_family_watch.sql in the SQL editor
```

## Deploy web viewer (Capa C)

1. Edit [`docs/watch/config.js`](watch/config.js) with CornerIQ `SUPABASE_URL` + anon key.
2. Upload `docs/watch/` to the static host (e.g. Azure alongside the partner deck) so the URL is:

`https://riderlabdeck.z21.web.core.windows.net/watch/?t=TOKEN`

3. Optional in `apps/mobile/.env`:

```
WATCH_SHARE_BASE_URL=https://riderlabdeck.z21.web.core.windows.net/watch/
```

## App flow

1. **Amigos → Círculo familiar** — add contacts (label and/or RiderLab friend).
2. During a ride → **Avisar a familia** — creates session, GPS pings (~2 min), opens share sheet.
3. Family opens the link (no app) or watches in-app if they are a linked friend.
4. Rider: Todo bien / Me detuve / Necesito ayuda / Compartir link / Parar.
5. Ending the ride ends the watch session and revokes tokens.
