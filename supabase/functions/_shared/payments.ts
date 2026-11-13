// The payment flows, written against small interfaces so they can be tested without Paystack or a
// database. The four functions in ../ wire these to the real services.
import {
  buildInitializeBody,
  buildRefundBody,
  isPaymentReference,
  judgeRefund,
  judgeTransaction,
  parseChargeSuccess,
  verifyWebhookSignature,
} from "./paystack.ts";
import { parseTransferEvent } from "./payouts.ts";

export interface BookingRow {
  id: string;
  status: string;
  amountKobo: number;
  reference: string;
  /** Set once the money has been recorded (escrow row exists). */
  paid: boolean;
  createdAt: string;
  /** False for a payment with no time limit (a puppy balance is paid at pick up). Default true. */
  holds?: boolean;
  /** "puppy" for puppy deposits and balances, "tag" for a QR tag order. Default "booking". */
  product?: "booking" | "puppy" | "tag" | "course";
}

export interface PaystackApi {
  initialize(
    body: Record<string, unknown>,
  ): Promise<{ status?: boolean; message?: string; data?: { authorization_url?: string } }>;
  verify(
    reference: string,
  ): Promise<{ status?: boolean; message?: string; data?: Record<string, unknown> | null }>;
  refund(
    body: Record<string, unknown>,
  ): Promise<{ status?: boolean; message?: string; data?: Record<string, unknown> | null }>;
}

export interface Db {
  /** The booking with this reference, only if it belongs to this user. */
  bookingForOwner(reference: string, userId: string): Promise<BookingRow | null>;
  /** The booking with this reference, whoever owns it (server side only). */
  bookingByReference(reference: string): Promise<BookingRow | null>;
  confirmPayment(
    reference: string,
    amountKobo: number,
  ): Promise<{ result: string; booking_id: string; booking_status: string }>;
  claimRefunds(
    limit: number,
  ): Promise<{ escrow_id: string; paystack_reference: string; refund_kobo: number }[]>;
  finishRefund(
    escrowId: string,
    ok: boolean,
    refundReference: string | null,
    error: string | null,
  ): Promise<void>;
  releaseDueBookings(): Promise<number>;
  /** Course refunds that staff queued: claimed here, sent to Paystack, then reported with finishCourseRefund. */
  claimCourseRefunds?(
    limit: number,
  ): Promise<{ purchase_id: string; paystack_reference: string; refund_kobo: number }[]>;
  finishCourseRefund?(
    purchaseId: string,
    ok: boolean,
    refundReference: string | null,
    error: string | null,
  ): Promise<void>;
  /** Paystack reported a payout transfer failed or was reversed: flag the payout item for staff. */
  markTransferFailed?(transferCode: string, reason: string | null): Promise<void>;
}

export interface Ctx {
  paystack: PaystackApi;
  db: Db;
  secret: string;
  callbackUrl?: string;
  /** How long an unpaid booking can still be paid, in minutes (settings.booking_hold_minutes). */
  holdMinutes?: number;
  now?: () => number;
}

export class HttpError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
  }
}

// ---------------------------------------------------------------------------------------------
// Start a payment: the app sends only the reference. The amount comes from the booking row.
// ---------------------------------------------------------------------------------------------
export async function initializePayment(
  ctx: Ctx,
  user: { id: string; email: string | null },
  input: { reference?: unknown },
): Promise<{ authorization_url: string; reference: string }> {
  if (!isPaymentReference(input.reference)) throw new HttpError(400, "Invalid payment reference");
  if (!user.email) throw new HttpError(400, "Your account has no email address");
  const booking = await ctx.db.bookingForOwner(input.reference, user.id);
  if (!booking) throw new HttpError(404, "Booking not found");
  if (booking.paid || booking.status !== "pending_payment") {
    throw new HttpError(409, "This booking is not waiting for payment");
  }
  const now = (ctx.now ?? Date.now)();
  const holdMs = (ctx.holdMinutes ?? 20) * 60_000;
  if (booking.holds !== false && now - Date.parse(booking.createdAt) > holdMs) {
    throw new HttpError(409, "This booking timed out. Please pick the time again.");
  }
  const res = await ctx.paystack.initialize(
    buildInitializeBody({
      email: user.email,
      amountKobo: booking.amountKobo,
      reference: booking.reference,
      callbackUrl: ctx.callbackUrl,
      bookingId: booking.id,
      product:
        booking.product === "puppy"
          ? "pawpass_puppy"
          : booking.product === "tag"
            ? "pawpass_tag"
            : booking.product === "course"
              ? "pawpass_course"
              : "pawpass_booking",
    }),
  );
  const url = res.data?.authorization_url;
  if (res.status !== true || !url) throw new HttpError(502, "Paystack could not start the payment");
  return { authorization_url: url, reference: booking.reference };
}

// ---------------------------------------------------------------------------------------------
// Check a payment. Safe to call any number of times; the database function is idempotent.
// ---------------------------------------------------------------------------------------------
export async function verifyPayment(
  ctx: Ctx,
  user: { id: string },
  input: { reference?: unknown },
): Promise<{ status: "paid" | "pending" | "failed"; booking_status?: string }> {
  if (!isPaymentReference(input.reference)) throw new HttpError(400, "Invalid payment reference");
  const booking = await ctx.db.bookingForOwner(input.reference, user.id);
  if (!booking) throw new HttpError(404, "Booking not found");
  if (booking.paid) return { status: "paid", booking_status: booking.status };

  const res = await ctx.paystack.verify(booking.reference);
  if (res.status !== true) throw new HttpError(502, "Paystack could not check the payment");
  const verdict = judgeTransaction(res.data, {
    reference: booking.reference,
    amountKobo: booking.amountKobo,
  });
  switch (verdict.kind) {
    case "pending":
      return { status: "pending" };
    case "failed":
      return { status: "failed" };
    case "mismatch":
      // Money moved but not the right money. Never confirm it; staff look at it.
      console.error("payment mismatch", booking.reference, verdict.reason);
      throw new HttpError(409, "The payment does not match this booking. Contact support.");
    case "paid": {
      const done = await ctx.db.confirmPayment(booking.reference, verdict.amountKobo);
      await processRefunds(ctx).catch((e) => console.error("refund run failed", e));
      return { status: "paid", booking_status: done.booking_status };
    }
  }
}

// ---------------------------------------------------------------------------------------------
// Paystack calls us. The signature proves it is them; the booking decides what the money is for.
// Returns an HTTP status: 200 means "stop retrying", 5xx means "try again".
// ---------------------------------------------------------------------------------------------
export async function handleWebhook(
  ctx: Ctx,
  rawBody: string,
  signature: string | null,
): Promise<{ status: number; body: string }> {
  if (!(await verifyWebhookSignature(rawBody, signature, ctx.secret))) {
    return { status: 401, body: "bad signature" };
  }
  const transfer = parseTransferEvent(rawBody);
  if (transfer) {
    if (transfer.kind === "failed") {
      try {
        await ctx.db.markTransferFailed?.(transfer.transferCode, transfer.reason);
      } catch (e) {
        console.error("transfer failure not recorded", transfer.transferCode, e);
        return { status: 500, body: "try again" };
      }
    }
    return { status: 200, body: "ok" };
  }
  const charge = parseChargeSuccess(rawBody);
  if (!charge) return { status: 200, body: "ignored" };
  if (charge.currency !== "NGN") return { status: 200, body: "ignored currency" };

  const booking = await ctx.db.bookingByReference(charge.reference);
  if (!booking) return { status: 200, body: "unknown reference" };

  try {
    await ctx.db.confirmPayment(charge.reference, charge.amountKobo);
  } catch (e) {
    if (e instanceof HttpError) throw e;
    const message = e instanceof Error ? e.message : String(e);
    // A wrong amount will never become right: record it and stop Paystack retrying.
    if (message.includes("does not match")) {
      console.error("webhook amount mismatch", charge.reference);
      return { status: 200, body: "amount mismatch" };
    }
    console.error("confirm failed", charge.reference, message);
    return { status: 500, body: "try again" };
  }
  await processRefunds(ctx).catch((e) => console.error("refund run failed", e));
  return { status: 200, body: "ok" };
}

// ---------------------------------------------------------------------------------------------
// Send queued refunds to Paystack, and release visits the owner never confirmed.
// ---------------------------------------------------------------------------------------------
/** Sends the refunds that are waiting: escrow refunds (bookings, puppies) and course refunds. */
export async function processRefunds(
  ctx: Ctx,
  limit = 20,
): Promise<{ sent: number; failed: number }> {
  let sent = 0;
  let failed = 0;
  const tally = (ok: boolean) => {
    if (ok) sent++;
    else failed++;
  };

  const queue = await ctx.db.claimRefunds(limit);
  for (const item of queue) {
    try {
      const res = await ctx.paystack.refund(
        buildRefundBody(item.paystack_reference, item.refund_kobo),
      );
      const verdict = judgeRefund(res);
      await ctx.db.finishRefund(
        item.escrow_id,
        verdict.ok,
        verdict.reference ?? null,
        verdict.error ?? null,
      );
      tally(verdict.ok);
    } catch (e) {
      console.error("refund call failed", item.escrow_id, e);
      failed++;
    }
  }

  // Course refunds are claimed on their own, so a problem with one kind never holds up the other.
  if (ctx.db.claimCourseRefunds && ctx.db.finishCourseRefund) {
    let courseQueue: { purchase_id: string; paystack_reference: string; refund_kobo: number }[] = [];
    try {
      courseQueue = await ctx.db.claimCourseRefunds(limit);
    } catch (e) {
      console.error("course refunds could not be claimed", e);
    }
    for (const item of courseQueue) {
      try {
        const res = await ctx.paystack.refund(
          buildRefundBody(item.paystack_reference, item.refund_kobo, "course"),
        );
        const verdict = judgeRefund(res);
        await ctx.db.finishCourseRefund(
          item.purchase_id,
          verdict.ok,
          verdict.reference ?? null,
          verdict.error ?? null,
        );
        tally(verdict.ok);
      } catch (e) {
        console.error("course refund call failed", item.purchase_id, e);
        failed++;
        // Say so, so it is tried again and the console shows why (not left claimed for 15 minutes).
        await ctx.db
          .finishCourseRefund(item.purchase_id, false, null, "Could not reach Paystack")
          .catch((err) => console.error("course refund result not recorded", err));
      }
    }
  }
  return { sent, failed };
}

export async function runScheduledJobs(
  ctx: Ctx,
): Promise<{ released: number; sent: number; failed: number }> {
  const released = await ctx.db.releaseDueBookings();
  const { sent, failed } = await processRefunds(ctx, 50);
  return { released, sent, failed };
}
