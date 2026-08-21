// Proxies Valhalla (Stadia Maps or self-host) so the API key never ships in the APK.
// Secrets: VALHALLA_URL (full POST URL), optional VALHALLA_API_KEY.

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

type Waypoint = { lat: number; lon: number };

function parseWaypoints(raw: unknown): Waypoint[] | null {
  if (!Array.isArray(raw) || raw.length < 2 || raw.length > 12) return null;
  const out: Waypoint[] = [];
  for (const item of raw) {
    if (!item || typeof item !== "object") return null;
    const rec = item as Record<string, unknown>;
    const lat = Number(rec.lat ?? rec.latitude);
    const lon = Number(rec.lon ?? rec.lng ?? rec.longitude);
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
    out.push({ lat, lon });
  }
  return out;
}

function costingFromPrefs(prefs: Record<string, unknown> | null) {
  const avoidTolls = prefs?.avoid_tolls === true;
  const allowHighway = prefs?.allow_highway !== false;
  const allowStreet = prefs?.allow_street !== false;
  const allowOffroad = prefs?.allow_offroad === true;
  const anyRoad = allowHighway || allowStreet || allowOffroad;
  if (!anyRoad && prefs == null) return {};

  if (!allowHighway && !allowStreet && !allowOffroad) {
    return {};
  }

  let useHighways = 0.5;
  if (!allowHighway) useHighways = 0.1;
  else if (!allowStreet) useHighways = 1.0;

  return {
    motorcycle: {
      use_tolls: avoidTolls ? 0 : 0.5,
      use_highways: useHighways,
      use_tracks: allowOffroad ? 0.8 : 0,
      use_trails: allowOffroad ? 0.6 : 0,
      exclude_unpaved: !allowOffroad,
    },
  };
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

  const waypoints = parseWaypoints(payload.waypoints);
  if (!waypoints) {
    return json(400, { error: "invalid_waypoints" });
  }

  const prefs =
    payload.prefs && typeof payload.prefs === "object"
      ? payload.prefs as Record<string, unknown>
      : null;

  const baseUrl = Deno.env.get("VALHALLA_URL")?.trim();
  if (!baseUrl) {
    return json(500, { error: "misconfigured" });
  }

  const apiKey = Deno.env.get("VALHALLA_API_KEY")?.trim();
  const url = new URL(baseUrl);
  if (apiKey && !url.searchParams.has("api_key")) {
    url.searchParams.set("api_key", apiKey);
  }

  const body = {
    locations: waypoints.map((w) => ({ lat: w.lat, lon: w.lon })),
    costing: "motorcycle",
    costing_options: costingFromPrefs(prefs),
    units: "kilometers",
    shape_format: "polyline6",
  };

  try {
    const upstream = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    const text = await upstream.text();
    let parsed: Record<string, unknown> = {};
    try {
      parsed = JSON.parse(text) as Record<string, unknown>;
    } catch {
      return json(502, { error: "upstream_invalid" });
    }
    if (!upstream.ok) {
      return json(upstream.status === 400 ? 422 : 502, {
        error: "no_route",
        detail: parsed.error ?? parsed.error_code ?? upstream.status,
      });
    }

    const trip = parsed.trip as Record<string, unknown> | undefined;
    const legs = Array.isArray(trip?.legs) ? trip!.legs : [];
    const shapes: string[] = [];
    for (const leg of legs) {
      if (!leg || typeof leg !== "object") continue;
      const shape = (leg as Record<string, unknown>).shape;
      if (typeof shape === "string" && shape.length > 0) shapes.push(shape);
    }
    if (shapes.length === 0) {
      return json(422, { error: "no_route" });
    }

    const summary = (trip?.summary ?? {}) as Record<string, unknown>;
    const lengthKm = Number(summary.length ?? 0);
    const timeS = Number(summary.time ?? 0);

    return json(200, {
      shapes,
      distance_m: Number.isFinite(lengthKm) ? lengthKm * 1000 : 0,
      duration_s: Number.isFinite(timeS) ? timeS : 0,
      provider: "valhalla",
    });
  } catch (e) {
    console.error("valhalla-route", e);
    return json(502, { error: "upstream_failed" });
  }
});
