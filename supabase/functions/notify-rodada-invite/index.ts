// Sends FCM for a rodada invite. Secret: FIREBASE_SERVICE_ACCOUNT (JSON).
// Uses service role to read invitee tokens; caller JWT must be host/cohost.

import { createClient } from "npm:@supabase/supabase-js@2";
import {
  cors,
  json,
  parseServiceAccount,
  sendFcmToTokens,
  serviceAccountParseDetail,
} from "../_shared/fcm.ts";

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
  if (!sa?.project_id || !sa.client_email || !sa.private_key) {
    return json(500, {
      error: "misconfigured",
      detail: serviceAccountParseDetail(),
    });
  }
  if (!supabaseUrl || !serviceKey) {
    return json(500, { error: "misconfigured", detail: "supabase" });
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
    console.log("notify-rodada-invite", JSON.stringify({
      rodadaId,
      invitees: userIds.size,
      tokens: 0,
      skipped: "no_tokens",
    }));
    return json(200, { sent: 0, skipped: "no_tokens" });
  }

  try {
    const sent = await sendFcmToTokens({
      admin,
      sa,
      tokens,
      payload: {
        title: notifTitle,
        body: notifBody,
        data: {
          type: "rodada_invite",
          rodada_id: rodadaId,
        },
        channelId: "riderlab_rodada_invites",
        androidPriority: "high",
      },
    });
    console.log("notify-rodada-invite", JSON.stringify({
      rodadaId,
      invitees: userIds.size,
      tokens: tokens.length,
      sent,
    }));
    return json(200, { sent });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("notify-rodada-invite", msg);
    return json(502, { error: "upstream_failed", detail: msg.slice(0, 80) });
  }
});
