import { createHmac } from "node:crypto";
import { beforeEach, describe, expect, it } from "vitest";
import {
  HttpError,
  handleWebhook,
  initializePayment,
  processRefunds,
  runScheduledJobs,
  verifyPayment,
  type BookingRow,
  type Ctx,
  type Db,
  type PaystackApi,
} from "./payments.ts";

const secret = "sk_test_fake_secret_for_tests";
const ref = "pp_" + "a".repeat(32);
const tolu = { id: "tolu", email: "tolu@example.com" };
const now = Date.parse("2026-11-05T08:00:00Z");

function booking(over: Partial<BookingRow> = {}): BookingRow {
  return {
    id: "b1",
    status: "pending_payment",
    amountKobo: 1500000,
    reference: ref,
    paid: false,
    createdAt: "2026-11-05T07:55:00Z",
    ...over,
  };
}

class FakeDb implements Db {
  rows = new Map<string, { owner: string; row: BookingRow }>();
  confirmed: { reference: string; amountKobo: number }[] = [];
  confirmError: Error | null = null;
  refunds: { escrow_id: string; paystack_reference: string; refund_kobo: number }[] = [];
  finished: { escrowId: string; ok: boolean; ref: string | null; error: string | null }[] = [];
  released = 0;
  failedTransfers: { code: string; reason: string | null }[] = [];
  transferError: Error | null = null;
  async markTransferFailed(code: string, reason: string | null) {
    if (this.transferError) throw this.transferError;
    this.failedTransfers.push({ code, reason });
  }

  add(owner: string, row: BookingRow) {
    this.rows.set(row.reference, { owner, row });
  }
  async bookingForOwner(reference: string, userId: string) {
    const r = this.rows.get(reference);
    return r && r.owner === userId ? r.row : null;
  }
  async bookingByReference(reference: string) {
    return this.rows.get(reference)?.row ?? null;
  }
  async confirmPayment(reference: string, amountKobo: number) {
    if (this.confirmError) throw this.confirmError;
    this.confirmed.push({ reference, amountKobo });
    const r = this.rows.get(reference)!;
    r.row.paid = true;
    r.row.status = "confirmed";
    return { result: "confirmed", booking_id: r.row.id, booking_status: "confirmed" };
  }
  async claimRefunds() {
    const out = this.refunds;
    this.refunds = [];
    return out;
  }
  async finishRefund(
    escrowId: string,
    ok: boolean,
    refundReference: string | null,
    error: string | null,
  ) {
    this.finished.push({ escrowId, ok, ref: refundReference, error });
  }
  async releaseDueBookings() {
    return this.released;
  }
  courseRefunds: { purchase_id: string; paystack_reference: string; refund_kobo: number }[] = [];
  courseFinished: { id: string; ok: boolean; ref: string | null; error: string | null }[] = [];
  courseClaimError: Error | null = null;
  async claimCourseRefunds() {
    if (this.courseClaimError) throw this.courseClaimError;
    const out = this.courseRefunds;
    this.courseRefunds = [];
    return out;
  }
  async finishCourseRefund(id: string, ok: boolean, ref: string | null, error: string | null) {
    this.courseFinished.push({ id, ok, ref, error });
  }
}

class FakePaystack implements PaystackApi {
  initBodies: Record<string, unknown>[] = [];
  initResult: Awaited<ReturnType<PaystackApi["initialize"]>> = {
    status: true,
    data: { authorization_url: "https://checkout.paystack.com/abc" },
  };
  verifyResult: Awaited<ReturnType<PaystackApi["verify"]>> = {
    status: true,
    data: { status: "success", reference: ref, amount: 1500000, currency: "NGN" },
  };
  refundBodies: Record<string, unknown>[] = [];
  refundResult: Awaited<ReturnType<PaystackApi["refund"]>> = {
    status: true,
    data: { status: "pending", id: 77 },
  };
  refundThrows = false;
  async initialize(body: Record<string, unknown>) {
    this.initBodies.push(body);
    return this.initResult;
  }
  async verify() {
    return this.verifyResult;
  }
  async refund(body: Record<string, unknown>) {
    if (this.refundThrows) throw new Error("network down");
    this.refundBodies.push(body);
    return this.refundResult;
  }
}

let db: FakeDb;
let ps: FakePaystack;
let ctx: Ctx;

beforeEach(() => {
  db = new FakeDb();
  ps = new FakePaystack();
  ctx = { db, paystack: ps, secret, now: () => now, holdMinutes: 20 };
  db.add("tolu", booking());
});

const status = async (p: Promise<unknown>) => {
  try {
    await p;
    return 200;
  } catch (e) {
    return e instanceof HttpError ? e.status : -1;
  }
};

describe("initializePayment", () => {
  it("asks Paystack for the booking's own amount and returns the checkout page", async () => {
    const out = await initializePayment(ctx, tolu, { reference: ref });
    expect(out).toEqual({ authorization_url: "https://checkout.paystack.com/abc", reference: ref });
    expect(ps.initBodies[0]).toMatchObject({
      amount: 1500000,
      email: "tolu@example.com",
      reference: ref,
      currency: "NGN",
    });
  });

  it("a client cannot choose the amount", async () => {
    await initializePayment(ctx, tolu, { reference: ref, amount: 1, amountKobo: 1 } as never);
    expect(ps.initBodies[0].amount).toBe(1500000);
  });

  it("refuses bad references, other people's bookings and unknown bookings", async () => {
    expect(await status(initializePayment(ctx, tolu, { reference: "nope" }))).toBe(400);
    expect(
      await status(initializePayment(ctx, { id: "kemi", email: "k@x.com" }, { reference: ref })),
    ).toBe(404);
    expect(await status(initializePayment(ctx, tolu, { reference: "pp_" + "b".repeat(32) }))).toBe(
      404,
    );
    expect(ps.initBodies).toHaveLength(0);
  });

  it("refuses an account with no email", async () => {
    expect(
      await status(initializePayment(ctx, { id: "tolu", email: null }, { reference: ref })),
    ).toBe(400);
  });

  it("refuses a booking that is already paid or no longer unpaid", async () => {
    db.rows.get(ref)!.row.paid = true;
    expect(await status(initializePayment(ctx, tolu, { reference: ref }))).toBe(409);
    db.rows.get(ref)!.row.paid = false;
    db.rows.get(ref)!.row.status = "cancelled";
    expect(await status(initializePayment(ctx, tolu, { reference: ref }))).toBe(409);
  });

  it("refuses once the hold has run out", async () => {
    db.rows.get(ref)!.row.createdAt = "2026-11-05T07:30:00Z";
    expect(await status(initializePayment(ctx, tolu, { reference: ref }))).toBe(409);
  });

  it("a puppy balance has no time limit; a deposit has", async () => {
    const bal = "pb_" + "b".repeat(32);
    db.add(
      "tolu",
      booking({
        reference: bal,
        status: "pending_payment",
        amountKobo: 30000000,
        createdAt: "2026-10-01T00:00:00Z",
        holds: false,
        product: "puppy",
      }),
    );
    const out = await initializePayment(ctx, tolu, { reference: bal });
    expect(out.reference).toBe(bal);
    expect(ps.initBodies[0]).toMatchObject({ amount: 30000000 });
    expect((ps.initBodies[0].metadata as Record<string, unknown>).product).toBe("pawpass_puppy");

    const dep = "pd_" + "d".repeat(32);
    db.add(
      "tolu",
      booking({ reference: dep, createdAt: "2026-10-01T00:00:00Z", holds: true, product: "puppy" }),
    );
    expect(await status(initializePayment(ctx, tolu, { reference: dep }))).toBe(409);
  });

  it("a Paystack failure is a 502", async () => {
    ps.initResult = { status: false, message: "Invalid key" };
    expect(await status(initializePayment(ctx, tolu, { reference: ref }))).toBe(502);
  });
});

describe("QR tag orders", () => {
  const tagRef = "pt_" + "d".repeat(32);
  const tagRow = (over: Partial<BookingRow> = {}) =>
    booking({ id: "t1", reference: tagRef, amountKobo: 450000, holds: false, product: "tag", ...over });

  it("starts a payment for the order's own total, however old the order is", async () => {
    db.add("tolu", tagRow({ createdAt: "2026-10-01T00:00:00Z" }));
    const out = await initializePayment(ctx, tolu, { reference: tagRef });
    expect(out.reference).toBe(tagRef);
    const body = ps.initBodies[0] as { amount: number; metadata: { product: string } };
    expect(body.amount).toBe(450000);
    expect(body.metadata.product).toBe("pawpass_tag");
  });

  it("a signed webhook confirms a tag payment", async () => {
    db.add("tolu", tagRow());
    const raw = JSON.stringify({
      event: "charge.success",
      data: { reference: tagRef, amount: 450000, currency: "NGN", status: "success" },
    });
    const sig = createHmac("sha512", secret).update(raw).digest("hex");
    expect((await handleWebhook(ctx, raw, sig)).status).toBe(200);
    expect(db.confirmed).toEqual([{ reference: tagRef, amountKobo: 450000 }]);
  });
});

describe("course purchases", () => {
  const courseRef = "pc_" + "e".repeat(32);
  const courseRow = (over: Partial<BookingRow> = {}) =>
    booking({ id: "c1", reference: courseRef, amountKobo: 250000, holds: false, product: "course", ...over });

  it("starts a payment for the course's price, however old the open purchase is", async () => {
    db.add("tolu", courseRow({ createdAt: "2026-10-01T00:00:00Z" }));
    const out = await initializePayment(ctx, tolu, { reference: courseRef });
    expect(out.reference).toBe(courseRef);
    const body = ps.initBodies[0] as { amount: number; metadata: { product: string } };
    expect(body.amount).toBe(250000);
    expect(body.metadata.product).toBe("pawpass_course");
  });

  it("will not start a payment for a course that is already paid for", async () => {
    db.add("tolu", courseRow({ paid: true, status: "paid" }));
    expect(await status(initializePayment(ctx, tolu, { reference: courseRef }))).toBe(409);
  });

  it("will not start a payment for someone else's purchase", async () => {
    db.add("kemi", courseRow());
    expect(await status(initializePayment(ctx, tolu, { reference: courseRef }))).toBe(404);
  });

  it("a signed webhook confirms a course payment at the amount Paystack received", async () => {
    db.add("tolu", courseRow());
    const raw = JSON.stringify({
      event: "charge.success",
      data: { reference: courseRef, amount: 250000, currency: "NGN", status: "success" },
    });
    const sig = createHmac("sha512", secret).update(raw).digest("hex");
    expect((await handleWebhook(ctx, raw, sig)).status).toBe(200);
    expect(db.confirmed).toEqual([{ reference: courseRef, amountKobo: 250000 }]);
  });

  it("a webhook for a purchase we do not have is ignored, not an error", async () => {
    const raw = JSON.stringify({
      event: "charge.success",
      data: { reference: courseRef, amount: 250000, currency: "NGN", status: "success" },
    });
    const sig = createHmac("sha512", secret).update(raw).digest("hex");
    expect(await handleWebhook(ctx, raw, sig)).toEqual({ status: 200, body: "unknown reference" });
  });
});

describe("course refunds", () => {
  const cRef = "pc_" + "f".repeat(32);

  it("sends a queued course refund for the full amount and says it went", async () => {
    db.courseRefunds = [{ purchase_id: "p1", paystack_reference: cRef, refund_kobo: 250000 }];
    expect(await processRefunds(ctx)).toEqual({ sent: 1, failed: 0 });
    expect(ps.refundBodies[0]).toMatchObject({ transaction: cRef, amount: 250000, currency: "NGN" });
    expect(ps.refundBodies[0].merchant_note).toBe("OurPawPass course refund");
    expect(db.courseFinished).toEqual([{ id: "p1", ok: true, ref: "77", error: null }]);
  });

  it("does both kinds of refund in one run", async () => {
    db.refunds = [{ escrow_id: "e1", paystack_reference: ref, refund_kobo: 1500000 }];
    db.courseRefunds = [{ purchase_id: "p1", paystack_reference: cRef, refund_kobo: 250000 }];
    expect(await processRefunds(ctx)).toEqual({ sent: 2, failed: 0 });
    expect(ps.refundBodies.map((b) => b.merchant_note)).toEqual(["OurPawPass booking refund", "OurPawPass course refund"]);
    expect(db.finished).toHaveLength(1);
    expect(db.courseFinished).toHaveLength(1);
  });

  it("a refusal from Paystack is reported with its reason, so it is tried again", async () => {
    db.courseRefunds = [{ purchase_id: "p1", paystack_reference: cRef, refund_kobo: 250000 }];
    ps.refundResult = { status: false, message: "Insufficient balance" };
    expect(await processRefunds(ctx)).toEqual({ sent: 0, failed: 1 });
    expect(db.courseFinished).toEqual([{ id: "p1", ok: false, ref: null, error: "Insufficient balance" }]);
  });

  it("a network failure is reported too, instead of leaving the refund claimed", async () => {
    db.courseRefunds = [{ purchase_id: "p1", paystack_reference: cRef, refund_kobo: 250000 }];
    ps.refundThrows = true;
    expect(await processRefunds(ctx)).toEqual({ sent: 0, failed: 1 });
    expect(db.courseFinished).toEqual([{ id: "p1", ok: false, ref: null, error: "Could not reach Paystack" }]);
  });

  it("a problem claiming course refunds does not stop the other refunds", async () => {
    db.refunds = [{ escrow_id: "e1", paystack_reference: ref, refund_kobo: 1500000 }];
    db.courseClaimError = new Error("database down");
    expect(await processRefunds(ctx)).toEqual({ sent: 1, failed: 0 });
  });

  it("does nothing extra when there are no course refunds", async () => {
    expect(await processRefunds(ctx)).toEqual({ sent: 0, failed: 0 });
  });

  it("the scheduled run sends course refunds as well", async () => {
    db.courseRefunds = [{ purchase_id: "p1", paystack_reference: cRef, refund_kobo: 250000 }];
    expect(await runScheduledJobs(ctx)).toEqual({ released: 0, sent: 1, failed: 0 });
  });
});

describe("verifyPayment", () => {
  it("records the payment when Paystack says the exact amount arrived", async () => {
    expect(await verifyPayment(ctx, tolu, { reference: ref })).toEqual({
      status: "paid",
      booking_status: "confirmed",
    });
    expect(db.confirmed).toEqual([{ reference: ref, amountKobo: 1500000 }]);
  });

  it("asking again after it is recorded does not record it twice", async () => {
    await verifyPayment(ctx, tolu, { reference: ref });
    expect(await verifyPayment(ctx, tolu, { reference: ref })).toMatchObject({ status: "paid" });
    expect(db.confirmed).toHaveLength(1);
  });

  it("pending and failed payments record nothing", async () => {
    ps.verifyResult = { status: true, data: { status: "ongoing" } };
    expect(await verifyPayment(ctx, tolu, { reference: ref })).toEqual({ status: "pending" });
    ps.verifyResult = { status: true, data: { status: "abandoned" } };
    expect(await verifyPayment(ctx, tolu, { reference: ref })).toEqual({ status: "failed" });
    expect(db.confirmed).toHaveLength(0);
  });

  it("a payment of the wrong amount is never recorded", async () => {
    ps.verifyResult = {
      status: true,
      data: { status: "success", reference: ref, amount: 100, currency: "NGN" },
    };
    expect(await status(verifyPayment(ctx, tolu, { reference: ref }))).toBe(409);
    expect(db.confirmed).toHaveLength(0);
  });

  it("only the owner can check", async () => {
    expect(await status(verifyPayment(ctx, { id: "kemi" }, { reference: ref }))).toBe(404);
    expect(await status(verifyPayment(ctx, tolu, { reference: "x" }))).toBe(400);
  });

  it("a Paystack outage is a 502, not a failed payment", async () => {
    ps.verifyResult = { status: false, message: "down" };
    expect(await status(verifyPayment(ctx, tolu, { reference: ref }))).toBe(502);
  });

  it("sends any refund that a late payment queued", async () => {
    db.confirmPayment = async (reference: string, amountKobo: number) => {
      db.confirmed.push({ reference, amountKobo });
      db.refunds.push({ escrow_id: "e1", paystack_reference: reference, refund_kobo: amountKobo });
      return { result: "refunded", booking_id: "b1", booking_status: "cancelled" };
    };
    expect(await verifyPayment(ctx, tolu, { reference: ref })).toMatchObject({
      booking_status: "cancelled",
    });
    expect(ps.refundBodies).toHaveLength(1);
    expect(db.finished[0]).toMatchObject({ escrowId: "e1", ok: true, ref: "77" });
  });
});

describe("handleWebhook", () => {
  const sign = (body: string) => createHmac("sha512", secret).update(body).digest("hex");
  const charge = (over: Record<string, unknown> = {}) =>
    JSON.stringify({
      event: "charge.success",
      data: { status: "success", reference: ref, amount: 1500000, currency: "NGN", ...over },
    });

  it("records a signed successful charge", async () => {
    const body = charge();
    expect(await handleWebhook(ctx, body, sign(body))).toEqual({ status: 200, body: "ok" });
    expect(db.confirmed).toEqual([{ reference: ref, amountKobo: 1500000 }]);
  });

  it("rejects a missing or wrong signature and records nothing", async () => {
    const body = charge();
    expect((await handleWebhook(ctx, body, null)).status).toBe(401);
    expect((await handleWebhook(ctx, body, sign(body + "x"))).status).toBe(401);
    expect(db.confirmed).toHaveLength(0);
  });

  it("a failed or reversed payout transfer is flagged; a successful one is just acknowledged", async () => {
    const failed = JSON.stringify({
      event: "transfer.failed",
      data: { transfer_code: "TRF_1", reason: "Account closed" },
    });
    expect(await handleWebhook(ctx, failed, sign(failed))).toEqual({ status: 200, body: "ok" });
    expect(db.failedTransfers).toEqual([{ code: "TRF_1", reason: "Account closed" }]);
    const ok = JSON.stringify({ event: "transfer.success", data: { transfer_code: "TRF_2" } });
    expect((await handleWebhook(ctx, ok, sign(ok))).status).toBe(200);
    expect(db.failedTransfers).toHaveLength(1);
  });

  it("an unsigned transfer event changes nothing, and a database error is retried", async () => {
    const failed = JSON.stringify({ event: "transfer.failed", data: { transfer_code: "TRF_1" } });
    expect((await handleWebhook(ctx, failed, null)).status).toBe(401);
    expect(db.failedTransfers).toHaveLength(0);
    db.transferError = new Error("db down");
    expect(await handleWebhook(ctx, failed, sign(failed))).toEqual({
      status: 500,
      body: "try again",
    });
  });

  it("a forged body with a real signature for another body is rejected", async () => {
    const real = charge({ amount: 1 });
    expect((await handleWebhook(ctx, charge(), sign(real))).status).toBe(401);
  });

  it("other events and unknown references are acknowledged and ignored", async () => {
    const other = JSON.stringify({ event: "transfer.success", data: {} });
    expect(await handleWebhook(ctx, other, sign(other))).toEqual({ status: 200, body: "ignored" });
    const unknown = charge({ reference: "pp_" + "c".repeat(32) });
    expect(await handleWebhook(ctx, unknown, sign(unknown))).toEqual({
      status: 200,
      body: "unknown reference",
    });
    const usd = charge({ currency: "USD" });
    expect((await handleWebhook(ctx, usd, sign(usd))).body).toBe("ignored currency");
    expect(db.confirmed).toHaveLength(0);
  });

  it("a wrong amount is refused by the database and not retried", async () => {
    db.confirmError = new Error("The amount paid does not match the booking");
    const body = charge({ amount: 5 });
    expect(await handleWebhook(ctx, body, sign(body))).toEqual({
      status: 200,
      body: "amount mismatch",
    });
  });

  it("a database outage asks Paystack to try again", async () => {
    db.confirmError = new Error("connection reset");
    const body = charge();
    expect((await handleWebhook(ctx, body, sign(body))).status).toBe(500);
  });

  it("the same event twice is harmless", async () => {
    const body = charge();
    await handleWebhook(ctx, body, sign(body));
    await handleWebhook(ctx, body, sign(body));
    expect(db.rows.get(ref)!.row.paid).toBe(true);
    expect(db.confirmed.length).toBeGreaterThanOrEqual(1);
  });
});

describe("processRefunds", () => {
  const item = { escrow_id: "e1", paystack_reference: ref, refund_kobo: 300000 };

  it("sends each queued refund once and records Paystack's id", async () => {
    db.refunds = [item, { ...item, escrow_id: "e2" }];
    expect(await processRefunds(ctx)).toEqual({ sent: 2, failed: 0 });
    expect(ps.refundBodies[0]).toMatchObject({ transaction: ref, amount: 300000 });
    expect(db.finished.map((f) => [f.escrowId, f.ok, f.ref])).toEqual([
      ["e1", true, "77"],
      ["e2", true, "77"],
    ]);
    expect(await processRefunds(ctx)).toEqual({ sent: 0, failed: 0 });
  });

  it("a refusal is recorded with Paystack's reason", async () => {
    db.refunds = [item];
    ps.refundResult = { status: false, message: "Transaction has already been fully reversed" };
    expect(await processRefunds(ctx)).toEqual({ sent: 0, failed: 1 });
    expect(db.finished[0]).toMatchObject({
      ok: false,
      error: "Transaction has already been fully reversed",
    });
  });

  it("a network error leaves the refund claimed so it is retried later", async () => {
    db.refunds = [item];
    ps.refundThrows = true;
    expect(await processRefunds(ctx)).toEqual({ sent: 0, failed: 1 });
    expect(db.finished).toHaveLength(0);
  });

  it("the scheduled run also releases unconfirmed visits", async () => {
    db.released = 3;
    db.refunds = [item];
    expect(await runScheduledJobs(ctx)).toEqual({ released: 3, sent: 1, failed: 0 });
  });
});
