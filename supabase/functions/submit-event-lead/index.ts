import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

const SOURCE = "simm-2026";

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function ipHash(req: Request): string {
  const cf = req.headers.get("cf-connecting-ip");
  const xff = req.headers.get("x-forwarded-for");
  const ip = (cf || (xff ? xff.split(",")[0] : "") || "0.0.0.0").trim();
  let h = 2166136261;
  for (let i = 0; i < ip.length; i++) {
    h ^= ip.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return (h >>> 0).toString(16);
}

async function overRate(
  admin: ReturnType<typeof createClient>,
  hash: string,
  kind: string,
  max: number,
): Promise<boolean> {
  const hourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  await admin.from("event_lead_rate").insert({ ip_hash: hash, kind });
  const { count } = await admin
    .from("event_lead_rate")
    .select("*", { count: "exact", head: true })
    .eq("ip_hash", hash)
    .eq("kind", kind)
    .gte("created_at", hourAgo);
  return (count ?? 0) > max;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim();
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();
  if (!supabaseUrl || !serviceKey) {
    return json(500, { ok: false, error: "misconfigured" });
  }

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const hash = ipHash(req);

  if (req.method === "GET") {
    if (await overRate(admin, hash, "hit", 80)) {
      return json(200, { ok: true });
    }
    await admin.rpc("event_bump_page_hit", { p_source: SOURCE });
    return json(200, { ok: true });
  }

  if (req.method !== "POST") {
    return json(405, { ok: false, error: "method_not_allowed" });
  }

  let body: Record<string, unknown> = {};
  try {
    body = (await req.json()) as Record<string, unknown>;
  } catch {
    return json(400, { ok: false, error: "bad_json" });
  }

  const hp = `${body.company ?? ""}${body.hp ?? ""}`.trim();
  if (hp) return json(200, { ok: true });

  if (await overRate(admin, hash, "lead", 8)) {
    return json(429, { ok: false, error: "rate_limited" });
  }

  if (body.consent !== true) {
    return json(400, { ok: false, error: "consent" });
  }

  const { data, error } = await admin.rpc("submit_event_lead", {
    p_name: body.name ?? "",
    p_platform: body.platform ?? "",
    p_email: body.email ?? "",
    p_phone: body.phone ?? "",
    p_source: SOURCE,
    p_utm: body.utm && typeof body.utm === "object" ? body.utm : {},
  });
  if (error) {
    console.error("submit_event_lead", error);
    return json(500, { ok: false, error: "insert_failed" });
  }
  const payload = (data ?? {}) as { ok?: boolean; error?: string; duplicate?: boolean };
  if (!payload.ok) {
    return json(400, { ok: false, error: payload.error ?? "invalid" });
  }
  return json(200, { ok: true, duplicate: Boolean(payload.duplicate) });
});
