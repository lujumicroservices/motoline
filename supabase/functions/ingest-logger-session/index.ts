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

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const dig = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(dig), (b) =>
    b.toString(16).padStart(2, "0"),
  ).join("");
}

type GnssLine = {
  t_us?: number;
  lat?: number;
  lng?: number;
  alt?: number;
  speed_mps?: number;
  heading?: number;
  acc_m?: number;
  utc_ms?: number;
  hpa?: number;
};

function parseNdjson(raw: string): GnssLine[] {
  const out: GnssLine[] = [];
  for (const line of raw.split("\n")) {
    const t = line.trim();
    if (!t) continue;
    try {
      out.push(JSON.parse(t) as GnssLine);
    } catch {
      // skip bad line
    }
  }
  return out;
}

function sessionStartedAt(manifest: Record<string, unknown>, lines: GnssLine[]): Date {
  const startedUs = Number(manifest.started_us ?? 0);
  if (startedUs > 0) {
    // Device boot-relative µs — use wall clock approx from ingest time − duration.
    const endedUs = Number(manifest.ended_us ?? startedUs);
    const durMs = Math.max(0, (endedUs - startedUs) / 1000);
    return new Date(Date.now() - durMs);
  }
  return new Date();
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (req.method !== "POST") {
    return json(405, { ok: false, error: "method_not_allowed" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim();
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();
  if (!supabaseUrl || !serviceKey) {
    return json(500, { ok: false, error: "misconfigured" });
  }

  let body: Record<string, unknown> = {};
  try {
    body = (await req.json()) as Record<string, unknown>;
  } catch {
    return json(400, { ok: false, error: "bad_json" });
  }

  // Firmware UploadTask sends X-Logger-Key + X-Device-Id (Azure contract).
  // Body device_secret remains for older helpers / tests.
  const headerKey = (req.headers.get("X-Logger-Key") ?? "").trim();
  const headerDev = (req.headers.get("X-Device-Id") ?? "").trim();
  const deviceId = String(body.device_id ?? headerDev ?? "").trim();
  const deviceSecret = String(body.device_secret ?? headerKey ?? "").trim();
  const sessionId = String(body.session_id ?? "").trim();
  if (!deviceId || !deviceSecret || !sessionId) {
    return json(400, { ok: false, error: "missing_fields" });
  }

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: device, error: devErr } = await admin
    .from("logger_devices")
    .select("device_id,user_id,secret_hash")
    .eq("device_id", deviceId)
    .maybeSingle();
  if (devErr) return json(500, { ok: false, error: devErr.message });
  if (!device) return json(401, { ok: false, error: "unknown_device" });

  const hash = await sha256Hex(deviceSecret);
  if (hash !== device.secret_hash) {
    return json(401, { ok: false, error: "bad_secret" });
  }

  await admin
    .from("logger_devices")
    .update({ last_seen_at: new Date().toISOString() })
    .eq("device_id", deviceId);

  const manifest =
    typeof body.manifest === "object" && body.manifest
      ? (body.manifest as Record<string, unknown>)
      : {};
  const gnssRaw = String(body.gnss_ndjson ?? "");
  const imuRaw = String(body.imu_ndjson ?? "");
  const lines = parseNdjson(gnssRaw);
  if (lines.length === 0) {
    return json(400, { ok: false, error: "no_gnss_points" });
  }

  const startedAt = sessionStartedAt(manifest, lines);
  const startedUs = Number(manifest.started_us ?? 0);
  let maxSpeed = 0;
  let speedSum = 0;
  let speedN = 0;
  let dist = 0;
  let prev: GnssLine | null = null;

  const points = lines
    .filter((l) => typeof l.lat === "number" && typeof l.lng === "number")
    .map((l) => {
      const tUs = Number(l.t_us ?? startedUs);
      const offsetMs = startedUs > 0 ? (tUs - startedUs) / 1000 : 0;
      const recorded = new Date(startedAt.getTime() + offsetMs);
      const spd = typeof l.speed_mps === "number" ? l.speed_mps : null;
      if (spd != null && spd > 0) {
        maxSpeed = Math.max(maxSpeed, spd);
        speedSum += spd;
        speedN++;
      }
      if (prev && typeof prev.lat === "number" && typeof prev.lng === "number") {
        // Haversine meters (approx)
        const R = 6371000;
        const p1 = (prev.lat! * Math.PI) / 180;
        const p2 = (l.lat! * Math.PI) / 180;
        const dp = ((l.lat! - prev.lat!) * Math.PI) / 180;
        const dl = ((l.lng! - prev.lng!) * Math.PI) / 180;
        const a =
          Math.sin(dp / 2) ** 2 +
          Math.cos(p1) * Math.cos(p2) * Math.sin(dl / 2) ** 2;
        dist += 2 * R * Math.asin(Math.min(1, Math.sqrt(a)));
      }
      prev = l;
      return {
        recorded_at: recorded.toISOString(),
        latitude: l.lat,
        longitude: l.lng,
        altitude: typeof l.alt === "number" ? l.alt : null,
        speed_mps: spd,
        accuracy_meters: typeof l.acc_m === "number" ? l.acc_m : null,
        heading: typeof l.heading === "number" ? l.heading : null,
        lean_degrees: null as number | null,
      };
    });

  const endedAt = points.length
    ? points[points.length - 1].recorded_at
    : startedAt.toISOString();

  const ridePayload = {
    user_id: device.user_id,
    local_id: sessionId,
    started_at: startedAt.toISOString(),
    ended_at: endedAt,
    distance_meters: dist,
    point_count: points.length,
    max_speed_mps: maxSpeed || null,
    avg_speed_mps: speedN ? speedSum / speedN : null,
    source: "m5_logger",
    title: `Logger ${deviceId}`,
    is_shared: false,
    visibility: "private",
    updated_at: new Date().toISOString(),
  };

  const { data: rideRow, error: rideErr } = await admin
    .from("rides")
    .upsert(ridePayload, { onConflict: "user_id,local_id" })
    .select("id")
    .maybeSingle();
  if (rideErr) return json(500, { ok: false, error: rideErr.message });
  const rideId = rideRow?.id as string | undefined;
  if (!rideId) return json(500, { ok: false, error: "no_ride_id" });

  // Replace points safely: insert then delete older if needed.
  await admin.from("track_points").delete().eq("ride_id", rideId);
  const chunk = 200;
  for (let i = 0; i < points.length; i += chunk) {
    const slice = points.slice(i, i + chunk).map((p) => ({
      ride_id: rideId,
      ...p,
    }));
    const { error: ptErr } = await admin.from("track_points").insert(slice);
    if (ptErr) return json(500, { ok: false, error: ptErr.message });
  }

  // 0.6.9i: the 20 Hz IMU is the file the laptop downloads. A failed store must not
  // return 200, or a KEEPSD-off device deletes the only copy.
  if (imuRaw.length > 0) {
    const imuPath = `logger-sessions/${device.user_id}/${sessionId}/imu20.ndjson`;
    const { error: imuErr } = await admin.storage.from("logger-sessions").upload(
      imuPath,
      new Blob([imuRaw], { type: "application/x-ndjson" }),
      { upsert: true, contentType: "application/x-ndjson" },
    );
    if (imuErr) {
      return json(500, { ok: false, error: "imu_store_failed", detail: imuErr.message });
    }
  }

  // Archive GNSS excerpt (best-effort). The IMU lives in imu20.ndjson, not here.
  try {
    const path = `logger-sessions/${device.user_id}/${sessionId}/payload.json`;
    await admin.storage.from("logger-sessions").upload(
      path,
      new Blob([JSON.stringify({
        manifest,
        gnss_ndjson: gnssRaw.slice(0, 500000),
        imu_bytes: imuRaw.length,
      })], { type: "application/json" }),
      { upsert: true },
    );
  } catch {
    // bucket may not exist yet — non-fatal for the GNSS excerpt
  }

  return json(200, {
    ok: true,
    ride_id: rideId,
    local_id: sessionId,
    point_count: points.length,
    imu_bytes: imuRaw.length,
  });
});
