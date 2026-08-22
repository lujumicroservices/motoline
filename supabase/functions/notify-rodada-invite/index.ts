// Sends FCM for a rodada invite. Secret: FIREBASE_SERVICE_ACCOUNT (JSON).
// Uses service role to read invitee tokens; caller JWT must be host/cohost.

import { createClient } from "npm:@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "npm:jose@5";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

type ServiceAccount = {
  project_id?: string;
  client_email?: string;
  private_key?: string;
};

function parseServiceAccount(): ServiceAccount | null {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")?.trim();
  if (!raw) return null;
  try {
    return JSON.parse(raw) as ServiceAccount;
  } catch {
    return null;
  }
}

function formatWhen(iso: string | null): string | null {
  if (!iso) return null;
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return null;
  try {
    return new Intl.DateTimeFormat("es-MX", {
      weekday: "short",
      day: "numeric",
      month: "short",
      hour: "2-digit",
      minute: "2-digit",
      timeZone: "America/Mexico_City",
    }).format(d);
  } catch {
    return d.toISOString();
  }
}

function formatKm(meters: number | null): string | null {
  if (meters == null || !Number.isFinite(meters) || meters <= 0) return null;
  const km = meters / 1000;
  if (km < 10) return `${km.toFixed(1)} km`;
  return `${Math.round(km)} km`;
}

async function fcmAccessToken(sa: ServiceAccount): Promise<string> {
  const email = sa.client_email?.trim();
  const pem = sa.private_key?.replace(/\\n/g, "\n");
  if (!email || !pem) throw new Error("misconfigured");
  const key = await importPKCS8(pem, "RS256");
  const now = Math.floor(Date.now() / 1000);
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const body = await res.json() as Record<string, unknown>;
  const token = body.access_token;
  if (typeof token !== "string" || !token) {
    throw new Error("oauth_failed");
  }
  return token;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (req.method !== "POST") {
    return json(405, { error: "method_not_allowed" });
  }

  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.toLowerCase().startsWith("bearer ")) {
    return json(401, { error: "unauthorized" });
  }

  let payload: Record<string, unknown> = {};
  try {
    payload = (await req.json()) as Record<string, unknown>;
  } catch {
    return json(400, { error: "invalid_json" });
  }

  const rodadaId = typeof payload.rodada_id === "string"
    ? payload.rodada_id.trim()
    : "";
  const userIdsRaw = payload.user_ids;
  const single = typeof payload.user_id === "string"
    ? payload.user_id.trim()
    : "";
  const userIds = new Set<string>();
  if (single) userIds.add(single);
  if (Array.isArray(userIdsRaw)) {
    for (const id of userIdsRaw) {
      if (typeof id === "string" && id.trim()) userIds.add(id.trim());
    }
  }
  if (!rodadaId || userIds.size === 0) {
    return json(400, { error: "invalid_payload" });
  }

  const sa = parseServiceAccount();
  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim();
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();
  if (!sa?.project_id || !supabaseUrl || !serviceKey) {
    return json(500, { error: "misconfigured" });
  }

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const caller = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY") ?? "", {
    global: { headers: { Authorization: auth } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userErr } = await caller.auth.getUser();
  if (userErr || !userData.user) {
    return json(401, { error: "unauthorized" });
  }
  const callerId = userData.user.id;

  const { data: membership } = await admin
    .from("rodada_members")
    .select("role")
    .eq("rodada_id", rodadaId)
    .eq("user_id", callerId)
    .maybeSingle();
  const role = (membership as { role?: string } | null)?.role;
  if (role !== "host" && role !== "cohost") {
    return json(403, { error: "forbidden" });
  }

  const { data: rodada } = await admin
    .from("rodadas")
    .select("title, destination, starts_at, route_distance_m, host_id")
    .eq("id", rodadaId)
    .maybeSingle();
  if (!rodada) return json(404, { error: "not_found" });

  const rec = rodada as Record<string, unknown>;
  const hostId = rec.host_id as string;
  const { data: hostRow } = await admin
    .from("profiles")
    .select("display_name")
    .eq("id", hostId)
    .maybeSingle();
  const hostName =
    ((hostRow as { display_name?: string } | null)?.display_name ?? "").trim() ||
    "Un rider";
  const title = ((rec.title as string) ?? "Rodada").trim() || "Rodada";
  const dest = (rec.destination as string | null)?.trim() || null;
  const when = formatWhen(rec.starts_at as string | null);
  const km = formatKm(
    rec.route_distance_m == null ? null : Number(rec.route_distance_m),
  );
  const bodyParts = [dest, when, km].filter(Boolean);
  const notifTitle = `${hostName} te invitó a ${title}`;
  const notifBody = bodyParts.length > 0
    ? bodyParts.join(" · ")
    : "Abre RiderLab para aceptar o rechazar.";

  const { data: tokenRows } = await admin
    .from("device_tokens")
    .select("token")
    .in("user_id", [...userIds]);
  const tokens = (tokenRows ?? [])
    .map((r) => (r as { token?: string }).token)
    .filter((t): t is string => typeof t === "string" && t.length > 0);
  if (tokens.length === 0) {
    return json(200, { sent: 0, skipped: "no_tokens" });
  }

  try {
    const access = await fcmAccessToken(sa);
    let sent = 0;
    for (const token of tokens) {
      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${access}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token,
              notification: { title: notifTitle, body: notifBody },
              data: {
                type: "rodada_invite",
                rodada_id: rodadaId,
              },
              android: {
                priority: "high",
                notification: { channel_id: "riderlab_rodada_invites" },
              },
            },
          }),
        },
      );
      if (res.ok) {
        sent++;
        continue;
      }
      const errText = await res.text();
      if (res.status === 404 || errText.includes("UNREGISTERED")) {
        await admin.from("device_tokens").delete().eq("token", token);
      } else {
        console.error("fcm send", res.status, errText.slice(0, 300));
      }
    }
    return json(200, { sent });
  } catch (e) {
    console.error("notify-rodada-invite", e);
    return json(502, { error: "upstream_failed" });
  }
});
