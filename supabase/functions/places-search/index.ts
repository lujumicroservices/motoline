// Proxies Google Places Text Search (New) so the API key never ships in the APK.
// Also reverse-geocodes a tap (Geocoding, then Nearby). Secret: GOOGLE_PLACES_API_KEY

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const REVERSE_COMPONENT_ORDER = [
  "neighborhood",
  "sublocality",
  "sublocality_level_1",
  "locality",
  "administrative_area_level_3",
  "administrative_area_level_2",
  "administrative_area_level_1",
];

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

function labelFromGeocode(result: Record<string, unknown>): string {
  const comps = Array.isArray(result.address_components)
    ? result.address_components
    : [];
  for (const wanted of REVERSE_COMPONENT_ORDER) {
    for (const row of comps) {
      if (!row || typeof row !== "object") continue;
      const rec = row as Record<string, unknown>;
      const types = Array.isArray(rec.types) ? rec.types : [];
      if (!types.includes(wanted)) continue;
      const name = typeof rec.long_name === "string" ? rec.long_name.trim() : "";
      if (name) return name;
    }
  }
  const formatted = typeof result.formatted_address === "string"
    ? result.formatted_address.trim()
    : "";
  return formatted.split(",")[0].trim();
}

async function reversePlace(
  lat: number,
  lng: number,
  apiKey: string,
): Promise<Record<string, unknown>[]> {
  const geoUrl = new URL("https://maps.googleapis.com/maps/api/geocode/json");
  geoUrl.searchParams.set("latlng", `${lat},${lng}`);
  geoUrl.searchParams.set("key", apiKey);
  geoUrl.searchParams.set("language", "es");
  geoUrl.searchParams.set("region", "mx");
  const geoRes = await fetch(geoUrl);
  const geoText = await geoRes.text();
  let geoParsed: Record<string, unknown> = {};
  try {
    geoParsed = JSON.parse(geoText) as Record<string, unknown>;
  } catch {
    geoParsed = {};
  }
  if (geoRes.ok && geoParsed.status === "OK") {
    const results = Array.isArray(geoParsed.results) ? geoParsed.results : [];
    for (const row of results) {
      if (!row || typeof row !== "object") continue;
      const rec = row as Record<string, unknown>;
      const title = labelFromGeocode(rec);
      if (!title) continue;
      const loc = rec.geometry as Record<string, unknown> | undefined;
      const locLatLng = loc?.location as Record<string, unknown> | undefined;
      const hitLat = Number(locLatLng?.lat);
      const hitLng = Number(locLatLng?.lng);
      return [{
        title,
        subtitle: typeof rec.formatted_address === "string"
          ? rec.formatted_address
          : null,
        lat: Number.isFinite(hitLat) ? hitLat : lat,
        lng: Number.isFinite(hitLng) ? hitLng : lng,
        primary_type: "geocode",
      }];
    }
  }

  const nearby = await fetch(
    "https://places.googleapis.com/v1/places:searchNearby",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": apiKey,
        "X-Goog-FieldMask":
          "places.displayName,places.formattedAddress,places.location,places.primaryType",
      },
      body: JSON.stringify({
        languageCode: "es",
        regionCode: "MX",
        maxResultCount: 1,
        locationRestriction: {
          circle: {
            center: { latitude: lat, longitude: lng },
            radius: 250,
          },
        },
      }),
    },
  );
  const nearbyText = await nearby.text();
  let nearbyParsed: Record<string, unknown> = {};
  try {
    nearbyParsed = JSON.parse(nearbyText) as Record<string, unknown>;
  } catch {
    return [];
  }
  if (!nearby.ok) return [];
  const places = Array.isArray(nearbyParsed.places) ? nearbyParsed.places : [];
  for (const row of places) {
    if (!row || typeof row !== "object") continue;
    const rec = row as Record<string, unknown>;
    const loc = rec.location as Record<string, unknown> | undefined;
    const hitLat = Number(loc?.latitude);
    const hitLng = Number(loc?.longitude);
    const display = rec.displayName as Record<string, unknown> | undefined;
    const title =
      (typeof display?.text === "string" ? display.text.trim() : "") ||
      (typeof rec.formattedAddress === "string"
        ? rec.formattedAddress.split(",")[0].trim()
        : "");
    if (!title) continue;
    return [{
      title,
      subtitle: typeof rec.formattedAddress === "string"
        ? rec.formattedAddress.trim()
        : null,
      lat: Number.isFinite(hitLat) ? hitLat : lat,
      lng: Number.isFinite(hitLng) ? hitLng : lng,
      primary_type: typeof rec.primaryType === "string" ? rec.primaryType : null,
    }];
  }
  return [];
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
  const lat = Number(payload.lat);
  const lng = Number(payload.lng);
  const isReverse = Number.isFinite(lat) &&
    Number.isFinite(lng) &&
    lat >= -90 &&
    lat <= 90 &&
    lng >= -180 &&
    lng <= 180 &&
    query.length < 2;
  if (!isReverse && (query.length < 2 || query.length > 200)) {
    return json(400, { error: "invalid_query" });
  }

  const apiKey = Deno.env.get("GOOGLE_PLACES_API_KEY")?.trim();
  if (!apiKey) {
    return json(500, { error: "misconfigured" });
  }

  if (isReverse) {
    try {
      const hits = await reversePlace(lat, lng, apiKey);
      return json(200, { hits, provider: "google_places" });
    } catch (e) {
      console.error("places-search reverse", e);
      return json(502, { error: "upstream_failed" });
    }
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
      const hitLat = Number(
        (rec.location as Record<string, unknown> | undefined)?.latitude,
      );
      const hitLng = Number(
        (rec.location as Record<string, unknown> | undefined)?.longitude,
      );
      if (!Number.isFinite(hitLat) || !Number.isFinite(hitLng)) continue;
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
        lat: hitLat,
        lng: hitLng,
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
