// FCM when a host/cohost starts a rodada (status → live).
// Secret: FIREBASE_SERVICE_ACCOUNT (JSON). Caller JWT must be host/cohost.

import { createClient } from "npm:@supabase/supabase-js@2";
import {
  cors,
  json,
  parseServiceAccount,
  sendFcmToTokens,
  serviceAccountParseDetail,
} from "../_shared/fcm.ts";

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
  if (!rodadaId) {
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
    .select("title, status, host_id")
    .eq("id", rodadaId)
    .maybeSingle();
  if (!rodada) return json(404, { error: "not_found" });
  const rec = rodada as { title?: string; status?: string; host_id?: string };
  if (rec.status !== "live") {
    return json(409, { error: "not_live" });
  }

  const { data: starterRow } = await admin
    .from("profiles")
    .select("display_name")
    .eq("id", callerId)
    .maybeSingle();
  const starterName =
    ((starterRow as { display_name?: string } | null)?.display_name ?? "")
      .trim() || "Un rider";
  const title = ((rec.title as string) ?? "Rodada").trim() || "Rodada";
  const notifTitle = `${title} ha iniciado`;
  const notifBody = `${starterName} puso la rodada en vivo.`;

  const { data: memberRows } = await admin
    .from("rodada_members")
    .select("user_id, rsvp")
    .eq("rodada_id", rodadaId);
  const recipientIds = (memberRows ?? [])
    .map((r) => r as { user_id?: string; rsvp?: string })
    .filter((r) =>
      typeof r.user_id === "string" &&
      r.user_id !== callerId &&
      r.rsvp !== "declined"
    )
    .map((r) => r.user_id as string);
  if (recipientIds.length === 0) {
    return json(200, { sent: 0, skipped: "no_recipients" });
  }

  const { data: tokenRows } = await admin
    .from("device_tokens")
    .select("token")
    .in("user_id", recipientIds);
  const tokens = (tokenRows ?? [])
    .map((r) => (r as { token?: string }).token)
    .filter((t): t is string => typeof t === "string" && t.length > 0);
  if (tokens.length === 0) {
    console.log("notify-rodada-started", JSON.stringify({
      rodadaId,
      recipients: recipientIds.length,
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
          type: "rodada_started",
          rodada_id: rodadaId,
        },
        channelId: "riderlab_rodada_started",
        androidPriority: "high",
      },
    });
    console.log("notify-rodada-started", JSON.stringify({
      rodadaId,
      recipients: recipientIds.length,
      tokens: tokens.length,
      sent,
    }));
    return json(200, { sent });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("notify-rodada-started", msg);
    return json(502, { error: "upstream_failed", detail: msg.slice(0, 80) });
  }
});
