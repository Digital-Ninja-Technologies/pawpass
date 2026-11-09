// Push notifications, written against small interfaces so the logic can be tested without Firebase or a database.
// The database decides what is pushed and to whom (see migration 20261116100000_push_notifications.sql); this builds
// the Firebase messages, sends them, and records how each notification went.

export interface PushRow {
  notificationId: string;
  tokenId: string;
  token: string;
  platform: string;
  title: string;
  body: string | null;
  link: string | null;
}

export interface PushDb {
  claim(limit: number): Promise<PushRow[]>;
  finish(notificationId: string, ok: boolean, deadTokenIds: string[]): Promise<void>;
}

export type SendResult = { kind: "sent" } | { kind: "dead" } | { kind: "retry"; error: string };

export interface Fcm {
  send(row: PushRow): Promise<SendResult>;
}

export interface PushCtx {
  db: PushDb;
  fcm: Fcm;
}

/** The Firebase (HTTP v1) message for one phone. Data values must all be strings. */
export function buildMessage(row: PushRow): { message: Record<string, unknown> } {
  const data: Record<string, string> = { notification_id: row.notificationId };
  if (row.link) data.link = row.link;
  return {
    message: {
      token: row.token,
      notification: { title: row.title, body: row.body ?? "" },
      data,
      android: { priority: "HIGH" },
      apns: { payload: { aps: { sound: "default" } } },
    },
  };
}

/**
 * Reads Firebase's answer. A token that no longer exists (the app was removed, or the token came from another
 * project) is "dead": stop using it. Anything else that went wrong may pass on its own, so it is tried again.
 */
export function judgeFcmResponse(status: number, body: unknown): SendResult {
  if (status >= 200 && status < 300) return { kind: "sent" };
  const err = (body as { error?: { status?: string; message?: string; details?: { errorCode?: string }[] } } | null)?.error;
  const codes = (err?.details ?? []).map((d) => d.errorCode);
  if (status === 404 || codes.includes("UNREGISTERED") || err?.status === "NOT_FOUND") return { kind: "dead" };
  if (codes.includes("SENDER_ID_MISMATCH")) return { kind: "dead" };
  if (status === 400 && err?.status === "INVALID_ARGUMENT" && /registration token/i.test(err?.message ?? "")) {
    return { kind: "dead" };
  }
  return { kind: "retry", error: `FCM ${status} ${err?.status ?? ""} ${(err?.message ?? "").slice(0, 120)}`.trim() };
}

export interface RunResult {
  notifications: number;
  sent: number;
  dead: number;
  retry: number;
}

/**
 * The scheduled job. Each notification goes to every phone of its owner. It counts as done when no phone needs a retry
 * (sent, or dead and switched off). One phone failing never stops the others.
 */
export async function runPush(ctx: PushCtx, limit = 100): Promise<RunResult> {
  const rows = await ctx.db.claim(limit);
  const byNotification = new Map<string, PushRow[]>();
  for (const row of rows) {
    const list = byNotification.get(row.notificationId);
    if (list) list.push(row);
    else byNotification.set(row.notificationId, [row]);
  }
  let sent = 0;
  let dead = 0;
  let retry = 0;
  for (const [notificationId, devices] of byNotification) {
    const deadTokens: string[] = [];
    let needsRetry = false;
    for (const device of devices) {
      let result: SendResult;
      try {
        result = await ctx.fcm.send(device);
      } catch (e) {
        result = { kind: "retry", error: e instanceof Error ? e.message : String(e) };
      }
      if (result.kind === "sent") sent++;
      else if (result.kind === "dead") {
        dead++;
        deadTokens.push(device.tokenId);
      } else {
        retry++;
        needsRetry = true;
        console.error("push not sent", device.tokenId, result.error);
      }
    }
    try {
      await ctx.db.finish(notificationId, !needsRetry, deadTokens);
    } catch (e) {
      console.error("push result not recorded", notificationId, e);
    }
  }
  return { notifications: byNotification.size, sent, dead, retry };
}

// ---------------------------------------------------------------------------------------------------------------
// Signing in to Google (service account key -> short lived access token)
// ---------------------------------------------------------------------------------------------------------------
export interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

export function parseServiceAccount(raw: string): ServiceAccount {
  let sa: Partial<ServiceAccount>;
  try {
    sa = JSON.parse(raw);
  } catch {
    throw new Error("FCM_SERVICE_ACCOUNT is not valid JSON");
  }
  if (!sa.client_email || !sa.private_key || !sa.project_id) {
    throw new Error("FCM_SERVICE_ACCOUNT is missing client_email, private_key or project_id");
  }
  return { client_email: sa.client_email, private_key: sa.private_key, project_id: sa.project_id };
}

function base64url(input: ArrayBuffer | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : new Uint8Array(input);
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function pemToDer(pem: string): Uint8Array<ArrayBuffer> {
  const body = pem
    .replace(/-----BEGIN [A-Z ]+-----/, "")
    .replace(/-----END [A-Z ]+-----/, "")
    .replace(/\s+/g, "");
  const bin = atob(body);
  const out = new Uint8Array(new ArrayBuffer(bin.length));
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

export const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
export const TOKEN_URL = "https://oauth2.googleapis.com/token";

/** The signed request Google exchanges for an access token (a JWT signed with the service account's key). */
export async function signServiceJwt(sa: ServiceAccount, nowSec: number): Promise<string> {
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64url(
    JSON.stringify({ iss: sa.client_email, scope: FCM_SCOPE, aud: TOKEN_URL, iat: nowSec, exp: nowSec + 3600 }),
  );
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claims}`));
  return `${header}.${claims}.${base64url(signature)}`;
}
