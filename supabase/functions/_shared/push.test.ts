import { generateKeyPairSync, webcrypto } from "node:crypto";
import { describe, expect, it, vi } from "vitest";
import {
  buildMessage,
  judgeFcmResponse,
  parseServiceAccount,
  runPush,
  signServiceJwt,
  type Fcm,
  type PushCtx,
  type PushDb,
  type PushRow,
  type SendResult,
} from "./push.ts";

const row = (n: string, t: string, link: string | null = "/bookings", body: string | null = "See you soon"): PushRow => ({
  notificationId: n,
  tokenId: t,
  token: `token-${t}`,
  platform: "android",
  title: "Booking confirmed",
  body,
  link,
});

function fakes(rows: PushRow[], send: (r: PushRow) => Promise<SendResult> | SendResult = () => ({ kind: "sent" })) {
  const finished: [string, boolean, string[]][] = [];
  const db: PushDb = {
    claim: vi.fn(async () => rows),
    finish: vi.fn(async (id, ok, dead) => {
      finished.push([id, ok, dead]);
    }),
  };
  const fcm: Fcm = { send: vi.fn(async (r) => send(r)) };
  const ctx: PushCtx = { db, fcm };
  return { ctx, db, fcm, finished };
}

describe("buildMessage", () => {
  it("sends the words and carries the link and id as strings", () => {
    const m = buildMessage(row("n1", "t1")).message as Record<string, unknown>;
    expect(m.token).toBe("token-t1");
    expect(m.notification).toEqual({ title: "Booking confirmed", body: "See you soon" });
    expect(m.data).toEqual({ notification_id: "n1", link: "/bookings" });
  });
  it("leaves the link out when there is none, and never sends a null body", () => {
    const m = buildMessage(row("n1", "t1", null, null)).message as Record<string, unknown>;
    expect(m.data).toEqual({ notification_id: "n1" });
    expect((m.notification as { body: string }).body).toBe("");
  });
});

describe("judgeFcmResponse", () => {
  it("accepts a 200", () => expect(judgeFcmResponse(200, { name: "projects/x/messages/1" })).toEqual({ kind: "sent" }));
  it("calls an unregistered token dead", () => {
    expect(judgeFcmResponse(404, { error: { status: "NOT_FOUND", details: [{ errorCode: "UNREGISTERED" }] } })).toEqual({ kind: "dead" });
  });
  it("calls a token from another project dead", () => {
    expect(judgeFcmResponse(403, { error: { status: "PERMISSION_DENIED", details: [{ errorCode: "SENDER_ID_MISMATCH" }] } })).toEqual({ kind: "dead" });
  });
  it("calls a malformed token dead, but not a malformed message", () => {
    expect(judgeFcmResponse(400, { error: { status: "INVALID_ARGUMENT", message: "The registration token is not a valid FCM registration token" } })).toEqual({ kind: "dead" });
    expect(judgeFcmResponse(400, { error: { status: "INVALID_ARGUMENT", message: "Invalid JSON payload received" } }).kind).toBe("retry");
  });
  it("retries on rate limits, server errors and sign in trouble", () => {
    for (const s of [401, 429, 500, 503]) expect(judgeFcmResponse(s, { error: { status: "X" } }).kind).toBe("retry");
  });
  it("copes with a body that is not JSON at all", () => expect(judgeFcmResponse(502, null).kind).toBe("retry"));
});

describe("runPush", () => {
  it("sends to every phone and records the notification as done", async () => {
    const { ctx, fcm, finished } = fakes([row("n1", "t1"), row("n1", "t2"), row("n2", "t3")]);
    const res = await runPush(ctx);
    expect(res).toEqual({ notifications: 2, sent: 3, dead: 0, retry: 0 });
    expect(fcm.send).toHaveBeenCalledTimes(3);
    expect(finished).toEqual([["n1", true, []], ["n2", true, []]]);
  });

  it("switches dead phones off and still counts the notification as done", async () => {
    const { ctx, finished } = fakes([row("n1", "t1"), row("n1", "t2")], (r) => (r.tokenId === "t1" ? { kind: "dead" } : { kind: "sent" }));
    const res = await runPush(ctx);
    expect(res).toMatchObject({ sent: 1, dead: 1, retry: 0 });
    expect(finished).toEqual([["n1", true, ["t1"]]]);
  });

  it("leaves a notification to be retried when a phone could not be reached, and still sends the rest", async () => {
    const { ctx, finished } = fakes([row("n1", "t1"), row("n1", "t2"), row("n2", "t3")], (r) => (r.tokenId === "t1" ? { kind: "retry", error: "503" } : { kind: "sent" }));
    const res = await runPush(ctx);
    expect(res).toMatchObject({ sent: 2, retry: 1 });
    expect(finished).toEqual([["n1", false, []], ["n2", true, []]]);
  });

  it("treats a thrown error (no network) as a retry", async () => {
    const { ctx, finished } = fakes([row("n1", "t1")], () => {
      throw new Error("network");
    });
    expect((await runPush(ctx)).retry).toBe(1);
    expect(finished).toEqual([["n1", false, []]]);
  });

  it("does nothing when nothing is ready", async () => {
    const { ctx, fcm } = fakes([]);
    expect(await runPush(ctx)).toEqual({ notifications: 0, sent: 0, dead: 0, retry: 0 });
    expect(fcm.send).not.toHaveBeenCalled();
  });
});

describe("service account", () => {
  const good = JSON.stringify({ client_email: "a@b.iam.gserviceaccount.com", private_key: "k", project_id: "p", extra: "ignored" });
  it("reads the three fields it needs", () => {
    expect(parseServiceAccount(good)).toEqual({ client_email: "a@b.iam.gserviceaccount.com", private_key: "k", project_id: "p" });
  });
  it("explains what is wrong", () => {
    expect(() => parseServiceAccount("not json")).toThrow(/not valid JSON/);
    expect(() => parseServiceAccount("{}")).toThrow(/missing/);
  });

  it("signs a JWT that Google can verify with the matching public key", async () => {
    const { privateKey, publicKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
    const pem = privateKey.export({ type: "pkcs8", format: "pem" }).toString();
    const jwt = await signServiceJwt({ client_email: "svc@x.iam.gserviceaccount.com", private_key: pem, project_id: "p" }, 1_800_000_000);
    const [h, c, s] = jwt.split(".");
    const decode = (v: string) => JSON.parse(Buffer.from(v, "base64url").toString());
    expect(decode(h)).toEqual({ alg: "RS256", typ: "JWT" });
    expect(decode(c)).toMatchObject({
      iss: "svc@x.iam.gserviceaccount.com",
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: 1_800_000_000,
      exp: 1_800_003_600,
    });
    const key = await webcrypto.subtle.importKey("spki", publicKey.export({ type: "spki", format: "der" }), { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
    const ok = await webcrypto.subtle.verify("RSASSA-PKCS1-v1_5", key, Buffer.from(s, "base64url"), new TextEncoder().encode(`${h}.${c}`));
    expect(ok).toBe(true);
  });
});
