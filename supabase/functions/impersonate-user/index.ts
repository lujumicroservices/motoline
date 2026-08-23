// Staff impersonation: mint a magic-link hash for a target user.
// Caller JWT must be in staff_admins (or IMPERSONATE_ADMIN_IDS).
// Never expose the service role key to the app.

import { createClient } from "npm:@supabase/supabase-js@2";

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

function adminIdsFromEnv(): Set<string> {
  const raw = Deno.env.get("IMPERSONATE_ADMIN_IDS") ?? "";
  return new Set(
    raw.split(/[,\s]+/).map((s) => s.trim()).filter((s) => s.length > 8),
  );
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
  const jwt = auth.slice("bearer ".length).trim();

  let payload: Record<string, unknown> = {};
  try {
    payload = (await req.json()) as Record<string, unknown>;
  } catch {
    return json(400, { error: "invalid_json" });
  }

  const action = typeof payload.action === "string"
    ? payload.action.trim()
    : "start";
  const query = typeof payload.q === "string" ? payload.q.trim() : "";
  const targetId = typeof payload.user_id === "string"
    ? payload.user_id.trim()
    : "";

  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim();
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();
  if (!supabaseUrl || !serviceKey) {
    return json(500, { error: "misconfigured" });
  }

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
  const caller = userData?.user;
  if (userErr || !caller) {
    return json(401, { error: "unauthorized" });
  }

  const { data: staffRow } = await admin
    .from("staff_admins")
    .select("user_id")
    .eq("user_id", caller.id)
    .maybeSingle();
  const allowEnv = adminIdsFromEnv();
  if (!staffRow && !allowEnv.has(caller.id)) {
    return json(403, { error: "forbidden" });
  }

  if (action === "search") {
    if (query.length < 2) {
      return json(400, { error: "query_too_short" });
    }
    const { data, error } = await admin.rpc("staff_search_riders", { q: query });
    if (error) {
      return json(500, { error: error.message });
    }
    const rows = Array.isArray(data) ? data : [];
    return json(200, {
      riders: rows.map((r: Record<string, unknown>) => ({
        id: r.id,
        display_name: r.display_name ?? null,
        email: r.email ?? null,
      })),
    });
  }

  if (action !== "start") {
    return json(400, { error: "invalid_action" });
  }
  if (!targetId) {
    return json(400, { error: "invalid_payload" });
  }
  if (targetId === caller.id) {
    return json(400, { error: "cannot_impersonate_self" });
  }

  const { data: targetUser, error: targetErr } = await admin.auth.admin
    .getUserById(targetId);
  const target = targetUser?.user;
  if (targetErr || !target) {
    return json(404, { error: "user_not_found" });
  }
  const email = target.email?.trim();
  if (!email) {
    return json(400, { error: "target_has_no_email" });
  }

  const { data: linkData, error: linkErr } = await admin.auth.admin
    .generateLink({
      type: "magiclink",
      email,
    });
  const hashed = linkData?.properties?.hashed_token;
  if (linkErr || !hashed) {
    return json(500, { error: linkErr?.message ?? "link_failed" });
  }

  const { data: profile } = await admin
    .from("profiles")
    .select("display_name")
    .eq("id", target.id)
    .maybeSingle();

  await admin.from("impersonation_audit").insert({
    admin_id: caller.id,
    target_id: target.id,
    client_info: "mobile",
  });

  const displayName = (profile?.display_name as string | null)?.trim() ||
    email;

  return json(200, {
    hashed_token: hashed,
    target: {
      id: target.id,
      email,
      display_name: displayName,
    },
  });
});
