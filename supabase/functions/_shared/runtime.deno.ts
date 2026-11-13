// Wiring for the real services (Deno / Supabase Edge Functions). Not unit tested: it is thin, and
// everything it calls is covered by payments.test.ts and the SQL tests.
import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { HttpError, type BookingRow, type Ctx, type Db, type PaystackApi } from "./payments.ts";
import { BlockedError, type AccountCtx } from "./accounts.ts";
import type { Mailer, ReminderCtx, ReminderDb, ReminderRow } from "./reminders.ts";
import {
  buildMessage,
  judgeFcmResponse,
  parseServiceAccount,
  signServiceJwt,
  TOKEN_URL,
  type Fcm,
  type PushCtx,
  type PushDb,
  type PushRow,
} from "./push.ts";
import { safeEqual } from "./paystack.ts";
import type { PayoutCtx, PayoutDb, PayoutItem, TransferApi } from "./payouts.ts";

declare const Deno: { env: { get(name: string): string | undefined } };

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function env(name: string): string {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`Missing secret: ${name}`);
  return v;
}

export function serviceClient(): SupabaseClient {
  return createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { persistSession: false },
  });
}

/** The person calling, from their own access token. Throws 401 if the token is missing or invalid. */
export async function callerFrom(req: Request): Promise<{ id: string; email: string | null }> {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) throw new HttpError(401, "Sign in first");
  const { data, error } = await serviceClient().auth.getUser(token);
  if (error || !data.user) throw new HttpError(401, "Sign in first");
  return { id: data.user.id, email: data.user.email ?? null };
}

/** True if the request carries the project's service role key (used by the scheduled job). */
export function isServiceCall(req: Request): boolean {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  return token.length > 0 && safeEqual(token, env("SUPABASE_SERVICE_ROLE_KEY"));
}

function paystack(secret: string): PaystackApi {
  const call = async (path: string, init?: RequestInit) => {
    const res = await fetch(`https://api.paystack.co${path}`, {
      ...init,
      headers: { Authorization: `Bearer ${secret}`, "Content-Type": "application/json" },
    });
    // Paystack answers errors with JSON too (status: false and a message), which the callers read.
    return await res
      .json()
      .catch(() => ({ status: false, message: `Paystack HTTP ${res.status}` }));
  };
  return {
    initialize: (body) =>
      call("/transaction/initialize", { method: "POST", body: JSON.stringify(body) }),
    verify: (reference) => call(`/transaction/verify/${encodeURIComponent(reference)}`),
    refund: (body) => call("/refund", { method: "POST", body: JSON.stringify(body) }),
  };
}

function db(client: SupabaseClient): Db {
  const must = <T>(res: { data: T; error: { message: string } | null }): T => {
    if (res.error) throw new Error(res.error.message);
    return res.data;
  };
  const bookingCols =
    "id, status, amount_kobo, paystack_reference, escrow_transaction_id, created_at, owner_user_id";
  const orderCols =
    "id, status, deposit_kobo, protection_fee_kobo, balance_kobo, deposit_reference, balance_reference, deposit_escrow_id, balance_escrow_id, created_at, updated_at, buyer_user_id";

  const bookingRow = (r: Record<string, unknown> | null): BookingRow | null =>
    r
      ? {
          id: r.id as string,
          status: r.status as string,
          amountKobo: Number(r.amount_kobo),
          reference: r.paystack_reference as string,
          paid: r.escrow_transaction_id !== null,
          createdAt: r.created_at as string,
        }
      : null;

  // A puppy deposit (pd_) is payable while the order waits for it; a balance (pb_) once the deposit is in.
  const orderRow = (r: Record<string, unknown> | null, reference: string): BookingRow | null => {
    if (!r) return null;
    const deposit = r.deposit_reference === reference;
    const status = r.status as string;
    return {
      id: r.id as string,
      status: deposit
        ? status === "pending_deposit"
          ? "pending_payment"
          : status
        : status === "deposit_paid"
          ? "pending_payment"
          : status,
      amountKobo: deposit
        ? Number(r.deposit_kobo) + Number(r.protection_fee_kobo)
        : Number(r.balance_kobo),
      reference,
      paid: deposit ? r.deposit_escrow_id !== null : r.balance_escrow_id !== null,
      createdAt: r.created_at as string,
      holds: deposit,
      product: "puppy",
    };
  };

  // A QR tag order (pt_) is a plain purchase: it waits for payment with no time limit, and no escrow is involved.
  const tagRow = (r: Record<string, unknown> | null): BookingRow | null =>
    r
      ? {
          id: r.id as string,
          status: r.status as string,
          amountKobo: Number(r.price_kobo) + Number(r.delivery_kobo),
          reference: r.paystack_reference as string,
          paid: r.status !== "pending_payment",
          createdAt: r.created_at as string,
          holds: false,
          product: "tag",
        }
      : null;

  // A course purchase (pc_) is the same kind of plain purchase: no time limit, no escrow.
  const courseRow = (r: Record<string, unknown> | null): BookingRow | null =>
    r
      ? {
          id: r.id as string,
          status: r.status as string,
          amountKobo: Number(r.amount_kobo),
          reference: r.paystack_reference as string,
          paid: r.status === "paid",
          createdAt: r.created_at as string,
          holds: false,
          product: "course",
        }
      : null;

  const find = async (reference: string, userId?: string): Promise<BookingRow | null> => {
    if (reference.startsWith("pc_")) {
      let q = client
        .from("course_purchases")
        .select("id, status, amount_kobo, paystack_reference, created_at, user_id")
        .eq("paystack_reference", reference);
      if (userId) q = q.eq("user_id", userId);
      return courseRow(must(await q.maybeSingle()));
    }
    if (reference.startsWith("pt_")) {
      let q = client
        .from("qr_tag_orders")
        .select("id, status, price_kobo, delivery_kobo, paystack_reference, created_at, user_id")
        .eq("paystack_reference", reference);
      if (userId) q = q.eq("user_id", userId);
      return tagRow(must(await q.maybeSingle()));
    }
    if (reference.startsWith("pp_")) {
      let q = client.from("bookings").select(bookingCols).eq("paystack_reference", reference);
      if (userId) q = q.eq("owner_user_id", userId);
      return bookingRow(must(await q.maybeSingle()));
    }
    const column = reference.startsWith("pd_") ? "deposit_reference" : "balance_reference";
    let q = client.from("puppy_orders").select(orderCols).eq(column, reference);
    if (userId) q = q.eq("buyer_user_id", userId);
    return orderRow(must(await q.maybeSingle()), reference);
  };

  return {
    bookingForOwner: (reference, userId) => find(reference, userId),
    bookingByReference: (reference) => find(reference),
    async confirmPayment(reference, amountKobo) {
      if (reference.startsWith("pc_")) {
        const r = must(
          await client.rpc("confirm_course_payment", {
            p_reference: reference,
            p_amount_kobo: amountKobo,
          }),
        ) as { result: string; order_id: string; order_status: string };
        return { result: r.result, booking_id: r.order_id, booking_status: r.order_status };
      }
      if (reference.startsWith("pt_")) {
        const r = must(
          await client.rpc("confirm_tag_payment", {
            p_reference: reference,
            p_amount_kobo: amountKobo,
          }),
        ) as { result: string; order_id: string; order_status: string };
        return { result: r.result, booking_id: r.order_id, booking_status: r.order_status };
      }
      if (reference.startsWith("pp_")) {
        return must(
          await client.rpc("confirm_booking_payment", {
            p_reference: reference,
            p_amount_kobo: amountKobo,
          }),
        );
      }
      const r = must(
        await client.rpc("confirm_order_payment", {
          p_reference: reference,
          p_amount_kobo: amountKobo,
        }),
      ) as { result: string; order_id: string; order_status: string };
      return { result: r.result, booking_id: r.order_id, booking_status: r.order_status };
    },
    async claimRefunds(limit) {
      return must(await client.rpc("claim_pending_refunds", { p_limit: limit })) ?? [];
    },
    async finishRefund(escrowId, ok, refundReference, error) {
      must(
        await client.rpc("finish_refund", {
          p_escrow: escrowId,
          p_ok: ok,
          p_refund_reference: refundReference,
          p_error: error,
        }),
      );
    },
    async markTransferFailed(transferCode, reason) {
      must(
        await client.rpc("mark_transfer_failed", {
          p_transfer_code: transferCode,
          p_reason: reason,
        }),
      );
    },
    async releaseDueBookings() {
      const bookings = must(await client.rpc("release_due_bookings")) as number;
      const orders = must(await client.rpc("release_due_orders")) as number;
      return bookings + orders;
    },
  };
}

export async function context(): Promise<Ctx> {
  const client = serviceClient();
  const { data } = await client
    .from("settings")
    .select("booking_hold_minutes")
    .limit(1)
    .maybeSingle();
  const secret = env("PAYSTACK_SECRET_KEY");
  return {
    paystack: paystack(secret),
    db: db(client),
    secret,
    callbackUrl: Deno.env.get("PAYSTACK_CALLBACK_URL") || undefined,
    holdMinutes: data?.booking_hold_minutes ?? 20,
  };
}

/** Turns a thrown error into a response: HttpError keeps its status, anything else is a plain 500. */
export function errorResponse(e: unknown): Response {
  if (e instanceof HttpError) return json({ error: e.message }, e.status);
  console.error(e);
  return json({ error: "Something went wrong. Please try again." }, 500);
}

// ---------------------------------------------------------------------------------------------------------------
// Payouts
// ---------------------------------------------------------------------------------------------------------------
function transferApi(secret: string): TransferApi {
  const post = async (path: string, body: Record<string, unknown>) => {
    const res = await fetch(`https://api.paystack.co${path}`, {
      method: "POST",
      headers: { Authorization: `Bearer ${secret}`, "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    return await res
      .json()
      .catch(() => ({ status: false, message: `Paystack HTTP ${res.status}` }));
  };
  return {
    createRecipient: (body) => post("/transferrecipient", body),
    transfer: (body) => post("/transfer", body),
  };
}

function payoutDb(client: SupabaseClient): PayoutDb {
  const must = <T>(res: { data: T; error: { message: string } | null }): T => {
    if (res.error) throw new Error(res.error.message);
    return res.data;
  };
  return {
    async schedule() {
      return (must(await client.rpc("schedule_payout_run")) as string | null) ?? null;
    },
    async claim(limit) {
      const rows = (must(await client.rpc("claim_payout_items", { p_limit: limit })) ??
        []) as Record<string, unknown>[];
      return rows.map((r): PayoutItem => ({
        itemId: r.item_id as string,
        partnerId: r.partner_id as string,
        amountKobo: Number(r.amount_kobo),
        bankCode: r.bank_code as string,
        accountNumber: r.account_number as string,
        accountName: r.account_name as string,
        recipientCode: (r.recipient_code as string | null) ?? null,
        attempts: Number(r.attempts),
      }));
    },
    async finish(itemId, ok, transferCode, error, recipientCode) {
      must(
        await client.rpc("finish_payout_item", {
          p_item: itemId,
          p_ok: ok,
          p_transfer_code: transferCode,
          p_error: error,
          p_recipient_code: recipientCode,
        }),
      );
    },
  };
}

export function payoutContext(): PayoutCtx {
  return { api: transferApi(env("PAYSTACK_SECRET_KEY")), db: payoutDb(serviceClient()) };
}

// ---------------------------------------------------------------------------------------------------------------
// Deleting an account
// ---------------------------------------------------------------------------------------------------------------
const FILE_BUCKETS = [
  "avatars",
  "chat-attachments",
  "dispute-evidence",
  "health-attachments",
  "partner-documents",
  "pet-photos",
  "post-media",
];

/** Every file path under a folder, including files in folders inside it. */
async function listFiles(client: SupabaseClient, bucket: string, prefix: string): Promise<string[]> {
  const { data, error } = await client.storage.from(bucket).list(prefix, { limit: 1000 });
  if (error) throw new Error(error.message);
  const out: string[] = [];
  for (const item of data ?? []) {
    const path = `${prefix}/${item.name}`;
    // A folder has no id; a file has one.
    if (item.id === null || item.id === undefined) out.push(...(await listFiles(client, bucket, path)));
    else out.push(path);
  }
  return out;
}

export function accountContext(): AccountCtx {
  const client = serviceClient();
  return {
    db: {
      async erase(userId) {
        const { error } = await client.rpc("erase_account", { p_user: userId });
        if (error) {
          if ((error as { code?: string }).code === "P0001") throw new BlockedError(error.message);
          throw new Error(error.message);
        }
      },
    },
    files: {
      async removeAll(userId) {
        let removed = 0;
        const problems: string[] = [];
        for (const bucket of FILE_BUCKETS) {
          try {
            const paths = await listFiles(client, bucket, userId);
            for (let i = 0; i < paths.length; i += 100) {
              const { error } = await client.storage.from(bucket).remove(paths.slice(i, i + 100));
              if (error) throw new Error(error.message);
            }
            removed += paths.length;
          } catch (e) {
            problems.push(`${bucket}: ${e instanceof Error ? e.message : String(e)}`);
          }
        }
        if (problems.length) throw new Error(problems.join("; "));
        return removed;
      },
    },
    auth: {
      async softDelete(userId) {
        // true = soft delete: keeps the row the payment records point at, wipes the email and phone.
        const { error } = await client.auth.admin.deleteUser(userId, true);
        if (error) throw new Error(error.message);
      },
    },
  };
}

// ---------------------------------------------------------------------------------------------------------------
// Reminders (scheduled job and email)
// ---------------------------------------------------------------------------------------------------------------
function resendMailer(apiKey: string): Mailer {
  return {
    async send(message) {
      const res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          from: message.from,
          to: [message.to],
          subject: message.subject,
          html: message.html,
          text: message.text,
        }),
      });
      if (res.ok) return { ok: true };
      const detail = await res.text().catch(() => "");
      return { ok: false, error: `Resend HTTP ${res.status} ${detail.slice(0, 200)}` };
    },
  };
}

function reminderDb(client: SupabaseClient): ReminderDb {
  const must = <T>(res: { data: T; error: { message: string } | null }): T => {
    if (res.error) throw new Error(res.error.message);
    return res.data;
  };
  return {
    async announce() {
      return Number(must(await client.rpc("announce_all_reminders")) ?? 0);
    },
    async claim(limit) {
      const rows = (must(await client.rpc("claim_reminder_emails", { p_limit: limit })) ??
        []) as Record<string, unknown>[];
      return rows.map((r): ReminderRow => ({
        notificationId: r.notification_id as string,
        email: r.email as string,
        firstName: (r.first_name as string | null) ?? "",
        title: r.title as string,
        body: (r.body as string | null) ?? "",
      }));
    },
    async finish(notificationId, ok) {
      must(
        await client.rpc("finish_reminder_email", { p_notification: notificationId, p_ok: ok }),
      );
    },
  };
}

/** Needs the RESEND_API_KEY secret. REMINDER_FROM is optional (default: PawPass <reminders@ourpawpass.com>). */
export function reminderContext(): ReminderCtx {
  return {
    db: reminderDb(serviceClient()),
    mailer: resendMailer(env("RESEND_API_KEY")),
    from: Deno.env.get("REMINDER_FROM") || "OurPawPass <reminders@ourpawpass.com>",
  };
}

// ---------------------------------------------------------------------------------------------------------------
// Push notifications (Firebase Cloud Messaging)
// ---------------------------------------------------------------------------------------------------------------
function pushDb(client: SupabaseClient): PushDb {
  const must = <T>(res: { data: T; error: { message: string } | null }): T => {
    if (res.error) throw new Error(res.error.message);
    return res.data;
  };
  return {
    async claim(limit) {
      const rows = (must(await client.rpc("claim_push_messages", { p_limit: limit })) ??
        []) as Record<string, unknown>[];
      return rows.map((r): PushRow => ({
        notificationId: r.notification_id as string,
        tokenId: r.token_id as string,
        token: r.token as string,
        platform: r.platform as string,
        title: r.title as string,
        body: (r.body as string | null) ?? null,
        link: (r.link as string | null) ?? null,
      }));
    },
    async finish(notificationId, ok, deadTokenIds) {
      must(
        await client.rpc("finish_push", {
          p_notification: notificationId,
          p_ok: ok,
          p_dead_tokens: deadTokenIds,
        }),
      );
    },
  };
}

function fcmSender(rawServiceAccount: string): Fcm {
  const sa = parseServiceAccount(rawServiceAccount);
  let cached: { token: string; expiresAt: number } | null = null;

  async function accessToken(): Promise<string> {
    const now = Math.floor(Date.now() / 1000);
    if (cached && cached.expiresAt - 60 > now) return cached.token;
    const assertion = await signServiceJwt(sa, now);
    const res = await fetch(TOKEN_URL, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }),
    });
    const body = (await res.json().catch(() => null)) as { access_token?: string; expires_in?: number } | null;
    if (!res.ok || !body?.access_token) throw new Error(`Google sign in failed (HTTP ${res.status})`);
    cached = { token: body.access_token, expiresAt: now + (body.expires_in ?? 3600) };
    return cached.token;
  }

  return {
    async send(row) {
      const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
        method: "POST",
        headers: { Authorization: `Bearer ${await accessToken()}`, "Content-Type": "application/json" },
        body: JSON.stringify(buildMessage(row)),
      });
      const body = await res.json().catch(() => null);
      return judgeFcmResponse(res.status, body);
    },
  };
}

/** Needs the FCM_SERVICE_ACCOUNT secret (the Firebase service account key, as JSON). */
export function pushContext(): PushCtx {
  return { db: pushDb(serviceClient()), fcm: fcmSender(env("FCM_SERVICE_ACCOUNT")) };
}
