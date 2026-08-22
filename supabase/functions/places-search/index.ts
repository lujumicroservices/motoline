// Proxies Google Places Text Search (New) so the API key never ships in the APK.
// Secret: GOOGLE_PLACES_API_KEY

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

function parseBounds(raw: unknown) {
  if (!raw || typeof raw !== "object") return null;
  const rec = raw as Record<string, unknown>;
  const south = Number(rec.south);
  const west = Number(rec.west);
  const north = Number(rec.north);
  const east = Number(rec.east);
  if (![south, west, north, east].every(Number.isFinite)) return null;
  if (south < -90 || north > 90 || south >= north) return null;
  if (west < -180 || east > 180) return null;
  return { south, west, north, east };
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

  const query = typeof payload.query === "string" ? payload.query.trim() : "";
  if (query.length < 2 || query.length > 200) {
    return json(400, { error: "invalid_query" });
  }

  const apiKey = Deno.env.get("GOOGLE_PLACES_API_KEY")?.trim();
  if (!apiKey) {
    return json(500, { error: "misconfigured" });
  }

  const limitRaw = Number(payload.limit ?? 10);
  const maxResultCount = Number.isFinite(limitRaw)
    ? Math.min(Math.max(Math.round(limitRaw), 1), 10)
    : 10;

  const bounds = parseBounds(payload.bounds);
  const body: Record<string, unknown> = {
    textQuery: query,
    languageCode: "es",
    regionCode: "MX",
    maxResultCount,
  };
  if (bounds) {
    body.locationBias = {
      rectangle: {
        low: { latitude: bounds.south, longitude: bounds.west },
        high: { latitude: bounds.north, longitude: bounds.east },
      },
    };
  }

  try {
    const upstream = await fetch(
      "https://places.googleapis.com/v1/places:searchText",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Goog-Api-Key": apiKey,
          "X-Goog-FieldMask":
            "places.displayName,places.formattedAddress,places.location,places.primaryType",
        },
        body: JSON.stringify(body),
      },
    );
    const text = await upstream.text();
    let parsed: Record<string, unknown> = {};
    try {
      parsed = JSON.parse(text) as Record<string, unknown>;
    } catch {
      return json(502, { error: "upstream_invalid" });
    }
    if (!upstream.ok) {
      return json(upstream.status >= 500 ? 502 : 422, {
        error: "places_failed",
        detail: parsed.error ?? upstream.status,
      });
    }

    const places = Array.isArray(parsed.places) ? parsed.places : [];
    const hits: Record<string, unknown>[] = [];
    for (const row of places) {
      if (!row || typeof row !== "object") continue;
      const rec = row as Record<string, unknown>;
      const loc = rec.location as Record<string, unknown> | undefined;
      const lat = Number(loc?.latitude);
      const lng = Number(loc?.longitude);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) continue;
      const display = rec.displayName as Record<string, unknown> | undefined;
      const title =
        (typeof display?.text === "string" ? display.text.trim() : "") ||
        (typeof rec.formattedAddress === "string"
          ? rec.formattedAddress.split(",")[0].trim()
          : "");
      if (!title) continue;
      const address =
        typeof rec.formattedAddress === "string"
          ? rec.formattedAddress.trim()
          : "";
      hits.push({
        title,
        subtitle: address && address !== title ? address : null,
        lat,
        lng,
        primary_type: typeof rec.primaryType === "string"
          ? rec.primaryType
          : null,
      });
    }

    return json(200, { hits, provider: "google_places" });
  } catch (e) {
    console.error("places-search", e);
    return json(502, { error: "upstream_failed" });
  }
});
