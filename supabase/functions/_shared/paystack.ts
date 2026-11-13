// Pure Paystack helpers: no network, no database, no Deno APIs. Everything here is unit tested
// (paystack.test.ts) because it decides whether money counts as received.

const encoder = new TextEncoder();

function toHex(bytes: ArrayBuffer): string {
  return [...new Uint8Array(bytes)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** Compares two strings without stopping at the first difference. */
export function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/** HMAC SHA512 of the raw request body, hex, which is what Paystack sends in `x-paystack-signature`. */
export async function signBody(rawBody: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-512" },
    false,
    ["sign"],
  );
  return toHex(await crypto.subtle.sign("HMAC", key, encoder.encode(rawBody)));
}

/** True only if the header is the signature of exactly this body made with our secret key. */
export async function verifyWebhookSignature(
  rawBody: string,
  header: string | null | undefined,
  secret: string,
): Promise<boolean> {
  if (!header || !secret) return false;
  return safeEqual(await signBody(rawBody, secret), header.trim().toLowerCase());
}

/** Booking references are made by `create_booking`: "pp_" and 32 hex characters. */
export function isBookingReference(ref: unknown): ref is string {
  return typeof ref === "string" && /^pp_[0-9a-f]{32}$/.test(ref);
}

/**
 * Every reference we make: "pp_" a booking, "pd_" a puppy deposit, "pb_" a puppy balance, "pt_" a QR tag order, "pc_" a course purchase, each followed by
 * 32 hex characters. Anything else is not ours and is never looked up.
 */
export function isPaymentReference(ref: unknown): ref is string {
  return typeof ref === "string" && /^(pp|pd|pb|pt|pc)_[0-9a-f]{32}$/.test(ref);
}

export interface Charge {
  reference: string;
  amountKobo: number;
  currency: string;
}

/** The payment details from a `charge.success` webhook, or null for any other event or a bad shape. */
export function parseChargeSuccess(raw: string): Charge | null {
  let event: unknown;
  try {
    event = JSON.parse(raw);
  } catch {
    return null;
  }
  if (typeof event !== "object" || event === null) return null;
  const e = event as { event?: unknown; data?: Record<string, unknown> };
  if (e.event !== "charge.success" || !e.data) return null;
  const { reference, amount, currency, status } = e.data;
  if (status !== "success" || !isPaymentReference(reference)) return null;
  if (typeof amount !== "number" || !Number.isInteger(amount) || amount <= 0) return null;
  return { reference, amountKobo: amount, currency: typeof currency === "string" ? currency : "" };
}

export type Verdict =
  | { kind: "paid"; amountKobo: number }
  | { kind: "pending" }
  | { kind: "failed" }
  | { kind: "mismatch"; reason: string };

/**
 * Reads Paystack's answer to "verify this transaction" against what we expected to be paid.
 * Money only counts when status is success, the currency is naira, the reference is ours, and the
 * amount is exactly what the booking costs.
 */
export function judgeTransaction(
  data: Record<string, unknown> | null | undefined,
  expected: { reference: string; amountKobo: number },
): Verdict {
  if (!data) return { kind: "pending" };
  const status = data.status;
  if (status === "failed" || status === "abandoned" || status === "reversed")
    return { kind: "failed" };
  if (status !== "success") return { kind: "pending" };
  if (data.reference !== expected.reference) return { kind: "mismatch", reason: "reference" };
  if (data.currency !== "NGN") return { kind: "mismatch", reason: "currency" };
  if (data.amount !== expected.amountKobo) return { kind: "mismatch", reason: "amount" };
  return { kind: "paid", amountKobo: expected.amountKobo };
}

export interface InitializeInput {
  email: string;
  amountKobo: number;
  reference: string;
  callbackUrl?: string;
  /** The booking or order this payment is for. */
  bookingId: string;
  product?: "pawpass_booking" | "pawpass_puppy" | "pawpass_tag" | "pawpass_course";
}

export function buildInitializeBody(i: InitializeInput): Record<string, unknown> {
  return {
    email: i.email,
    amount: i.amountKobo,
    currency: "NGN",
    reference: i.reference,
    channels: ["card", "bank", "bank_transfer", "ussd"],
    ...(i.callbackUrl ? { callback_url: i.callbackUrl } : {}),
    metadata: { booking_id: i.bookingId, product: i.product ?? "pawpass_booking" },
  };
}

export function buildRefundBody(
  reference: string,
  amountKobo: number,
  what: "booking" | "course" = "booking",
): Record<string, unknown> {
  return {
    transaction: reference,
    amount: amountKobo,
    currency: "NGN",
    customer_note: "Refund from OurPawPass",
    merchant_note: `OurPawPass ${what} refund`,
  };
}

/** Paystack accepts a refund as pending or processed; anything else (or `status: false`) is a failure. */
export function judgeRefund(res: {
  status?: unknown;
  message?: unknown;
  data?: Record<string, unknown> | null;
}): {
  ok: boolean;
  reference?: string;
  error?: string;
} {
  if (res.status !== true) {
    return {
      ok: false,
      error: typeof res.message === "string" ? res.message : "Paystack refused the refund",
    };
  }
  const state = res.data?.status;
  if (state === "failed" || state === "needs-attention") {
    return { ok: false, error: `Paystack refund status: ${String(state)}` };
  }
  const id = res.data?.id;
  return { ok: true, reference: id === undefined || id === null ? undefined : String(id) };
}
