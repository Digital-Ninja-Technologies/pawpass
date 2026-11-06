import { createHmac } from "node:crypto";
import { describe, expect, it } from "vitest";
import {
  buildInitializeBody,
  buildRefundBody,
  isBookingReference,
  isPaymentReference,
  judgeRefund,
  judgeTransaction,
  parseChargeSuccess,
  safeEqual,
  signBody,
  verifyWebhookSignature,
} from "./paystack.ts";

const secret = "sk_test_fake_secret_for_tests";
const ref = "pp_" + "a".repeat(32);

describe("webhook signature", () => {
  const body = JSON.stringify({ event: "charge.success", data: { reference: ref } });
  const good = createHmac("sha512", secret).update(body).digest("hex");

  it("matches Paystack's HMAC SHA512", async () => {
    expect(await signBody(body, secret)).toBe(good);
    expect(await verifyWebhookSignature(body, good, secret)).toBe(true);
  });

  it("accepts the hex in any case and with spaces around it", async () => {
    expect(await verifyWebhookSignature(body, ` ${good.toUpperCase()} `, secret)).toBe(true);
  });

  it("refuses a different body, a different key, a missing or empty signature", async () => {
    expect(await verifyWebhookSignature(body + " ", good, secret)).toBe(false);
    expect(await verifyWebhookSignature(body, good, "sk_test_other")).toBe(false);
    expect(await verifyWebhookSignature(body, null, secret)).toBe(false);
    expect(await verifyWebhookSignature(body, "", secret)).toBe(false);
    expect(await verifyWebhookSignature(body, good.slice(0, -1), secret)).toBe(false);
  });

  it("refuses everything when the secret is not set", async () => {
    const empty = createHmac("sha512", "").update(body).digest("hex");
    expect(await verifyWebhookSignature(body, empty, "")).toBe(false);
  });

  it("safeEqual compares whole strings", () => {
    expect(safeEqual("abc", "abc")).toBe(true);
    expect(safeEqual("abc", "abd")).toBe(false);
    expect(safeEqual("abc", "ab")).toBe(false);
  });
});

describe("references", () => {
  it("only accepts the shape create_booking makes", () => {
    expect(isBookingReference(ref)).toBe(true);
    for (const bad of [
      "",
      "pp_",
      "pp_" + "A".repeat(32),
      "pp_" + "a".repeat(31),
      "xx_" + "a".repeat(32),
      12,
      null,
      undefined,
      "pp_" + "a".repeat(32) + "x",
    ]) {
      expect(isBookingReference(bad)).toBe(false);
    }
  });
});

describe("payment references", () => {
  it("accepts bookings, puppy deposits, puppy balances and tag orders, and nothing else", () => {
    for (const p of ["pp", "pd", "pb", "pt"]) {
      expect(isPaymentReference(`${p}_${"a".repeat(32)}`)).toBe(true);
    }
    for (const bad of [
      "px_" + "a".repeat(32),
      "pd_" + "A".repeat(32),
      "pd_" + "a".repeat(31),
      "",
      null,
      5,
      "pd_" + "a".repeat(32) + "0",
    ]) {
      expect(isPaymentReference(bad)).toBe(false);
    }
  });

  it("a puppy deposit charge is understood like a booking charge", () => {
    const ref = "pd_" + "c".repeat(32);
    const raw = JSON.stringify({
      event: "charge.success",
      data: { status: "success", reference: ref, amount: 15750000, currency: "NGN" },
    });
    expect(parseChargeSuccess(raw)).toEqual({
      reference: ref,
      amountKobo: 15750000,
      currency: "NGN",
    });
  });

  it("the initialize body says which product it is for", () => {
    expect(
      buildInitializeBody({
        email: "a@b.c",
        amountKobo: 1,
        reference: "pd_" + "a".repeat(32),
        bookingId: "o1",
        product: "pawpass_puppy",
      }).metadata,
    ).toEqual({ booking_id: "o1", product: "pawpass_puppy" });
  });
});

describe("charge.success", () => {
  const event = (over: Record<string, unknown> = {}, top: Record<string, unknown> = {}) =>
    JSON.stringify({
      event: "charge.success",
      data: { status: "success", reference: ref, amount: 1500000, currency: "NGN", ...over },
      ...top,
    });

  it("reads the reference, amount and currency", () => {
    expect(parseChargeSuccess(event())).toEqual({
      reference: ref,
      amountKobo: 1500000,
      currency: "NGN",
    });
  });

  it("ignores other events, bad JSON and odd shapes", () => {
    expect(parseChargeSuccess(event({}, { event: "refund.processed" }))).toBeNull();
    expect(parseChargeSuccess("not json")).toBeNull();
    expect(parseChargeSuccess("null")).toBeNull();
    expect(parseChargeSuccess(JSON.stringify({ event: "charge.success" }))).toBeNull();
    expect(parseChargeSuccess(event({ status: "failed" }))).toBeNull();
    expect(parseChargeSuccess(event({ reference: "someone-elses-ref" }))).toBeNull();
    expect(parseChargeSuccess(event({ amount: "1500000" }))).toBeNull();
    expect(parseChargeSuccess(event({ amount: 0 }))).toBeNull();
    expect(parseChargeSuccess(event({ amount: 10.5 }))).toBeNull();
  });
});

describe("judging a verified transaction", () => {
  const expected = { reference: ref, amountKobo: 1500000 };
  const tx = (over: Record<string, unknown> = {}) => ({
    status: "success",
    reference: ref,
    amount: 1500000,
    currency: "NGN",
    ...over,
  });

  it("paid only when status, reference, currency and amount all agree", () => {
    expect(judgeTransaction(tx(), expected)).toEqual({ kind: "paid", amountKobo: 1500000 });
  });

  it("underpaying or overpaying is a mismatch, never paid", () => {
    expect(judgeTransaction(tx({ amount: 1499999 }), expected)).toEqual({
      kind: "mismatch",
      reason: "amount",
    });
    expect(judgeTransaction(tx({ amount: 1500001 }), expected)).toEqual({
      kind: "mismatch",
      reason: "amount",
    });
  });

  it("another currency or another reference is a mismatch", () => {
    expect(judgeTransaction(tx({ currency: "USD" }), expected)).toEqual({
      kind: "mismatch",
      reason: "currency",
    });
    expect(judgeTransaction(tx({ reference: "pp_" + "b".repeat(32) }), expected)).toEqual({
      kind: "mismatch",
      reason: "reference",
    });
  });

  it("unfinished payments are pending; abandoned, failed and reversed ones are failed", () => {
    for (const s of ["pending", "ongoing", "processing", "queued", "something-new"]) {
      expect(judgeTransaction(tx({ status: s }), expected)).toEqual({ kind: "pending" });
    }
    for (const s of ["failed", "abandoned", "reversed"]) {
      expect(judgeTransaction(tx({ status: s }), expected)).toEqual({ kind: "failed" });
    }
    expect(judgeTransaction(null, expected)).toEqual({ kind: "pending" });
  });

  it("a string amount from Paystack is not trusted as a number", () => {
    expect(judgeTransaction(tx({ amount: "1500000" }), expected)).toEqual({
      kind: "mismatch",
      reason: "amount",
    });
  });
});

describe("request bodies", () => {
  it("initialize sends the booking's own amount in kobo, in naira, with our reference", () => {
    const body = buildInitializeBody({
      email: "tolu@example.com",
      amountKobo: 1500000,
      reference: ref,
      bookingId: "b1",
    });
    expect(body).toMatchObject({
      email: "tolu@example.com",
      amount: 1500000,
      currency: "NGN",
      reference: ref,
    });
    expect(body.channels).toEqual(["card", "bank", "bank_transfer", "ussd"]);
    expect(body).not.toHaveProperty("callback_url");
    expect(
      buildInitializeBody({
        email: "a@b.c",
        amountKobo: 1,
        reference: ref,
        bookingId: "b",
        callbackUrl: "https://x.y/z",
      }),
    ).toHaveProperty("callback_url", "https://x.y/z");
  });

  it("refund names the original transaction and the amount to return", () => {
    expect(buildRefundBody(ref, 300000)).toMatchObject({
      transaction: ref,
      amount: 300000,
      currency: "NGN",
    });
  });
});

describe("judging a refund response", () => {
  it("pending or processed is accepted, with Paystack's id", () => {
    expect(judgeRefund({ status: true, data: { status: "pending", id: 99 } })).toEqual({
      ok: true,
      reference: "99",
    });
    expect(judgeRefund({ status: true, data: { status: "processed" } })).toEqual({
      ok: true,
      reference: undefined,
    });
  });

  it("a refusal or failed state keeps the reason", () => {
    expect(judgeRefund({ status: false, message: "Transaction not found" })).toEqual({
      ok: false,
      error: "Transaction not found",
    });
    expect(judgeRefund({ status: false })).toEqual({
      ok: false,
      error: "Paystack refused the refund",
    });
    expect(judgeRefund({ status: true, data: { status: "failed" } }).ok).toBe(false);
    expect(judgeRefund({ status: true, data: { status: "needs-attention" } }).ok).toBe(false);
  });
});
