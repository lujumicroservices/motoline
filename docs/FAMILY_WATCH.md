# Family Watch (círculo + link web)

## Apply DB

```bash
supabase db push
# migrations:
# - supabase/migrations/20260815220000_family_watch.sql
# - supabase/migrations/20260816010000_family_watch_security.sql
```

## Deploy web viewer (Capa C)

1. Edit [`docs/watch/config.js`](watch/config.js) with RiderLab `SUPABASE_URL` + anon key.
2. Upload `docs/watch/` to the static host (e.g. Azure alongside the partner deck) so the URL is:

`https://riderlabdeck.z21.web.core.windows.net/watch/?t=TOKEN`

3. Optional in `apps/mobile/.env`:

```
WATCH_SHARE_BASE_URL=https://riderlabdeck.z21.web.core.windows.net/watch/
```

## App flow

1. **Amigos → Círculo familiar** — add contacts (label and/or RiderLab friend).
2. During a **solo ride** or a **Rodada** (Live tab / heart in app bar) → **Avisar a familia**.
3. Creates session + GPS pings (~2 min) and opens the share sheet.
4. **Enviar a otro** reuses the **same** URL so earlier recipients keep working.
5. **Nuevo link** intentionally invalidates prior magic links (leak / lost phone).
6. Family opens the link (no app) or watches in-app if they are a linked friend.
7. Rider: Todo bien / Me detuve / Necesito ayuda / Parar.
8. Ending the ride or stopping watch ends the session and revokes tokens.

Pack **Compartir en vivo** (rodada map) is separate from the family WhatsApp link.

## Security model (current)

| Control | Behavior |
|--------|----------|
| Token storage | Raw token only on device; DB stores SHA-256 hash |
| Expiry | 12 hours from issue |
| End ride / Parar | Revokes all tokens for the session |
| Ended session | Public RPC returns `ended` (no position) |
| Rate limit | ~60 polls/min per token |
| Access audit | `watch_share_access` rows on each successful public read |
| Rotate | Explicit “Nuevo link” only — never on normal resend |

## Recommendations (product + ops)

**Already worth doing / keep:**
- Prefer WhatsApp/Signal DMs over posting the link in group chats.
- Use **Nuevo link** if the URL was forwarded too widely or the phone was shared.
- Stop watch as soon as you arrive / park.

**Next hardening (backlog):**
1. **Passphrase gate** on the web page (rider sets a short PIN; family types it once).
2. **Coarse mode** (~100–200 m fuzz) for low-risk check-ins; precise for SOS.
3. **Viewer cap** (e.g. max N distinct opens) then require rotate.
4. **Push/SMS** to trusted contacts instead of a forwardable URL when possible.
5. **Device binding** / short-lived refresh tokens for the web viewer.
6. Show rider a simple “opened N times” counter from `watch_share_access`.

Family Watch is **not** emergency services (not 911 / 911 MX).
