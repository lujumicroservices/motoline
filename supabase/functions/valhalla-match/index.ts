// Map-matches a GPS trace via Valhalla `/trace_attributes`.
// Reuses VALHALLA_URL / VALHALLA_API_KEY (same secrets as valhalla-route).
// The stored URL is the /route endpoint; this rewrites it to /trace_attributes.

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const MAX_SHAPE = 2000;
const MIN_SHAPE = 2;

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

type LatLon = { lat: number; lon: number };

function parseShape(raw: unknown): LatLon[] | null {
  if (!Array.isArray(raw) || raw.length < MIN_SHAPE || raw.length > MAX_SHAPE) {
    return null;
  }
  const out: LatLon[] = [];
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

/** `…/route/v1` → `…/trace_attributes/v1` (Stadia and most Valhalla hosts). */
function traceAttributesUrl(routeUrl: string): string {
  const u = new URL(routeUrl);
  u.pathname = u.pathname.replace(/\/route(\/|$)/, "/trace_attributes$1");
  return u.toString();
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

  const shape = parseShape(payload.shape ?? payload.points);
  if (!shape) {
    return json(400, { error: "invalid_shape" });
  }

  const baseUrl = Deno.env.get("VALHALLA_URL")?.trim();
  if (!baseUrl) {
    return json(500, { error: "misconfigured" });
  }

  const apiKey = Deno.env.get("VALHALLA_API_KEY")?.trim();
  const url = new URL(traceAttributesUrl(baseUrl));
  if (apiKey && !url.searchParams.has("api_key")) {
    url.searchParams.set("api_key", apiKey);
  }

  const body = {
    shape: shape.map((p) => ({ lat: p.lat, lon: p.lon })),
    costing: "motorcycle",
    shape_match: "map_snap",
    shape_format: "polyline6",
    filters: {
      attributes: ["shape"],
      action: "include",
    },
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
        error: "no_match",
        detail: parsed.error ?? parsed.error_code ?? upstream.status,
      });
    }

    const polyline = typeof parsed.shape === "string" ? parsed.shape : "";
    if (!polyline) {
      return json(422, { error: "no_match" });
    }

    return json(200, {
      polyline,
      shape_format: "polyline6",
      provider: "valhalla",
    });
  } catch (e) {
    console.error("valhalla-match", e);
    return json(502, { error: "upstream_failed" });
  }
});
