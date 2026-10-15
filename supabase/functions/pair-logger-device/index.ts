import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function randomSecret(bytes = 24): string {
  const arr = new Uint8Array(bytes);
  crypto.getRandomValues(arr);
  return Array.from(arr, (b) => b.toString(16).padStart(2, "0")).join("");
}

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const dig = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(dig), (b) =>
    b.toString(16).padStart(2, "0"),
  ).join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (req.method !== "POST") {
    return json(405, { ok: false, error: "method_not_allowed" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim();
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")?.trim();
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();
  if (!supabaseUrl || !anonKey || !serviceKey) {
    return json(500, { ok: false, error: "misconfigured" });
  }

  const auth = req.headers.get("Authorization") ?? "";
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: auth } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData.user) {
    return json(401, { ok: false, error: "unauthorized" });
  }
  const userId = userData.user.id;

  let body: Record<string, unknown> = {};
  try {
    body = (await req.json()) as Record<string, unknown>;
  } catch {
    return json(400, { ok: false, error: "bad_json" });
  }

  const action = String(body.action ?? "mint_code");
  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  async function createDeviceFor(ownerId: string, label: string) {
    const deviceId = `m5-${randomSecret(6)}`;
    const secret = randomSecret(24);
    const secretHash = await sha256Hex(secret);

    const { error: insErr } = await admin.from("logger_devices").insert({
      device_id: deviceId,
      user_id: ownerId,
      secret_hash: secretHash,
      label,
    });
    if (insErr) {
      return {
        ok: false as const,
        status: 500,
        error: insErr.message,
        step: "insert_device",
      };
    }

    return {
      ok: true as const,
      device_id: deviceId,
      device_secret: secret,
      ingest_url: `${supabaseUrl}/functions/v1/ingest-logger-session`,
      user_id: ownerId,
    };
  }

  if (action === "mint_code") {
    const code = randomSecret(4).slice(0, 8).toUpperCase();
    const expires = new Date(Date.now() + 15 * 60 * 1000).toISOString();
    const { error } = await admin.from("logger_pair_codes").insert({
      code,
      user_id: userId,
      expires_at: expires,
    });
    if (error) {
      return json(500, { ok: false, error: error.message, step: "mint_code" });
    }
    return json(200, { ok: true, code, expires_at: expires });
  }

  // BLE / in-app: one hop for the signed-in rider (no short-lived code).
  if (action === "create_device") {
    const label = String(body.label ?? "M5 Logger").slice(0, 64);
    const created = await createDeviceFor(userId, label);
    if (!created.ok) {
      return json(created.status, {
        ok: false,
        error: created.error,
        step: created.step,
      });
    }
    return json(200, created);
  }

  if (action === "claim_code") {
    // USB helper: claim a code minted on the phone → device_id + secret.
    const code = String(body.code ?? "").trim().toUpperCase();
    const label = String(body.label ?? "M5 Logger").slice(0, 64);
    if (!code) return json(400, { ok: false, error: "missing_code" });

    const { data: row, error } = await admin
      .from("logger_pair_codes")
      .select("*")
      .eq("code", code)
      .maybeSingle();
    if (error) {
      return json(500, { ok: false, error: error.message, step: "lookup_code" });
    }
    if (!row || row.consumed_at) {
      return json(400, { ok: false, error: "invalid_code" });
    }
    if (new Date(row.expires_at).getTime() < Date.now()) {
      return json(400, { ok: false, error: "expired" });
    }

    const created = await createDeviceFor(String(row.user_id), label);
    if (!created.ok) {
      return json(created.status, {
        ok: false,
        error: created.error,
        step: created.step,
      });
    }

    await admin
      .from("logger_pair_codes")
      .update({ consumed_at: new Date().toISOString() })
      .eq("code", code);

    return json(200, created);
  }

  return json(400, { ok: false, error: "unknown_action" });
});
