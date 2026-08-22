// Shared FCM helpers for rodada push. Secret: FIREBASE_SERVICE_ACCOUNT (JSON).

import { SignJWT, importPKCS8 } from "npm:jose@5";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

export function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

export type ServiceAccount = {
  project_id?: string;
  client_email?: string;
  private_key?: string;
};

export function parseServiceAccount(): ServiceAccount | null {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")?.trim();
  if (!raw) return null;
  try {
    let parsed: unknown = JSON.parse(raw);
    if (typeof parsed === "string") {
      parsed = JSON.parse(parsed);
    }
    if (!parsed || typeof parsed !== "object") return null;
    return parsed as ServiceAccount;
  } catch {
    return null;
  }
}

export async function fcmAccessToken(sa: ServiceAccount): Promise<string> {
  const email = sa.client_email?.trim();
  const pem = sa.private_key?.replace(/\\n/g, "\n");
  if (!email || !pem) throw new Error("misconfigured");
  const key = await importPKCS8(pem, "RS256");
  const now = Math.floor(Date.now() / 1000);
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const body = await res.json() as Record<string, unknown>;
  const token = body.access_token;
  if (typeof token !== "string" || !token) {
    throw new Error("oauth_failed");
  }
  return token;
}

export type FcmPayload = {
  title: string;
  body: string;
  data: Record<string, string>;
  channelId: string;
  androidPriority?: "high" | "normal";
  interruptionLevel?: "time-sensitive" | "active";
};

export async function sendFcmToTokens(opts: {
  admin: SupabaseClient;
  sa: ServiceAccount;
  tokens: string[];
  payload: FcmPayload;
}): Promise<number> {
  const access = await fcmAccessToken(opts.sa);
  const projectId = opts.sa.project_id!;
  let sent = 0;
  for (const token of opts.tokens) {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${access}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: {
              title: opts.payload.title,
              body: opts.payload.body,
            },
            data: opts.payload.data,
            android: {
              priority: opts.payload.androidPriority ?? "high",
              notification: {
                channel_id: opts.payload.channelId,
                notification_priority: opts.payload.interruptionLevel ===
                    "time-sensitive"
                  ? "PRIORITY_MAX"
                  : "PRIORITY_HIGH",
                default_vibrate_timings:
                  opts.payload.interruptionLevel === "time-sensitive",
                visibility: "PUBLIC",
              },
            },
            apns: {
              headers: { "apns-priority": "10" },
              payload: {
                aps: {
                  sound: "default",
                  "interruption-level": opts.payload.interruptionLevel ??
                    "active",
                },
              },
            },
          },
        }),
      },
    );
    if (res.ok) {
      sent++;
      continue;
    }
    const errText = await res.text();
    if (res.status === 404 || errText.includes("UNREGISTERED")) {
      await opts.admin.from("device_tokens").delete().eq("token", token);
    } else {
      console.error("fcm send", res.status, errText.slice(0, 300));
    }
  }
  return sent;
}
