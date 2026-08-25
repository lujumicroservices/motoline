// Deletes the caller's auth user (and cascaded cloud rows).
// Requires a valid user JWT. Uses the service role only on the server.

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

  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim();
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();
  if (!supabaseUrl || !serviceKey) {
    return json(500, { error: "misconfigured" });
  }

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
  const user = userData?.user;
  if (userErr || !user) {
    return json(401, { error: "unauthorized" });
  }

  // Best-effort storage cleanup for rodada photos uploaded by this user.
  try {
    const { data: photos } = await admin
      .from("rodada_photos")
      .select("storage_path")
      .eq("user_id", user.id);
    const paths = (photos ?? [])
      .map((p: { storage_path?: string }) => p.storage_path)
      .filter((p): p is string => typeof p === "string" && p.length > 0);
    if (paths.length > 0) {
      await admin.storage.from("rodada-photos").remove(paths);
    }
  } catch (e) {
    console.error("rodada photo cleanup:", e);
  }

  const { error: delErr } = await admin.auth.admin.deleteUser(user.id);
  if (delErr) {
    console.error("deleteUser:", delErr);
    return json(500, { error: "delete_failed", detail: delErr.message });
  }

  return json(200, { ok: true });
});
