// FCM for rodada radio. Alerts (kind=safety) use max-priority channel.
// Caller JWT must be the message author and a member. Secret: FIREBASE_SERVICE_ACCOUNT.

import { createClient } from "npm:@supabase/supabase-js@2";
import {
  cors,
  json,
  parseServiceAccount,
  sendFcmToTokens,
  serviceAccountParseDetail,
} from "../_shared/fcm.ts";

function clip(text: string, max: number): string {
  const t = text.trim();
  if (t.length <= max) return t;
  return `${t.slice(0, max - 1)}…`;
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
  const messageId = typeof payload.message_id === "string"
    ? payload.message_id.trim()
    : "";
  if (!rodadaId || !messageId) {
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
    .select("role, rsvp")
    .eq("rodada_id", rodadaId)
    .eq("user_id", callerId)
    .maybeSingle();
  if (!membership) return json(403, { error: "forbidden" });

  const { data: msg } = await admin
    .from("rodada_messages")
    .select("id, rodada_id, user_id, body, kind")
    .eq("id", messageId)
    .eq("rodada_id", rodadaId)
    .maybeSingle();
  if (!msg) return json(404, { error: "not_found" });
  const rec = msg as {
    user_id: string;
    body?: string;
    kind?: string;
  };
  if (rec.user_id !== callerId) return json(403, { error: "forbidden" });
  const kind = rec.kind === "safety" ? "safety" : "text";
  if (rec.kind === "system") {
    return json(200, { sent: 0, skipped: "system" });
  }

  const { data: rodada } = await admin
    .from("rodadas")
    .select("title")
    .eq("id", rodadaId)
    .maybeSingle();
  const title =
    ((rodada as { title?: string } | null)?.title ?? "Rodada").trim() ||
    "Rodada";

  const { data: senderRow } = await admin
    .from("profiles")
    .select("display_name")
    .eq("id", callerId)
    .maybeSingle();
  const senderName =
    ((senderRow as { display_name?: string } | null)?.display_name ?? "")
      .trim() || "Un rider";

  const bodyText = clip(rec.body ?? "", 180);
  const isAlert = kind === "safety";
  const notifTitle = isAlert
    ? `ALERTA · ${title}`
    : `${senderName} · radio`;
  const notifBody = isAlert
    ? `${senderName}: ${bodyText || "Necesito ayuda"}`
    : (bodyText || title);

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
    console.log("notify-rodada-radio", JSON.stringify({
      rodadaId,
      kind,
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
          type: isAlert ? "rodada_alert" : "rodada_radio",
          kind,
          rodada_id: rodadaId,
          tab: "radio",
        },
        channelId: isAlert
          ? "riderlab_rodada_alerts"
          : "riderlab_rodada_radio",
        androidPriority: "high",
        interruptionLevel: isAlert ? "time-sensitive" : "active",
      },
    });
    console.log("notify-rodada-radio", JSON.stringify({
      rodadaId,
      kind,
      recipients: recipientIds.length,
      tokens: tokens.length,
      sent,
    }));
    return json(200, { sent });
  } catch (e) {
    const msgText = e instanceof Error ? e.message : String(e);
    console.error("notify-rodada-radio", msgText);
    return json(502, { error: "upstream_failed", detail: msgText.slice(0, 80) });
  }
});
