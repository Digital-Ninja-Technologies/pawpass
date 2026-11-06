import { describe, expect, it } from "vitest";
import {
  accountProblem,
  buildRecipientBody,
  buildTransferBody,
  judgeTransfer,
  parseTransferEvent,
  runPayouts,
  sendItem,
  transferReference,
  type PayoutCtx,
  type PayoutDb,
  type PayoutItem,
  type TransferApi,
} from "./payouts.ts";

const id = "123e4567-e89b-12d3-a456-426614174000";

function item(over: Partial<PayoutItem> = {}): PayoutItem {
  return {
    itemId: id,
    partnerId: "p1",
    amountKobo: 1408000,
    bankCode: "058",
    accountNumber: "0123456789",
    accountName: "Paws and Claws",
    recipientCode: null,
    attempts: 1,
    ...over,
  };
}

class FakeDb implements PayoutDb {
  queue: PayoutItem[] = [];
  scheduled: string | null = "run-1";
  finished: {
    itemId: string;
    ok: boolean;
    code: string | null;
    error: string | null;
    recipient: string | null;
  }[] = [];
  async schedule() {
    return this.scheduled;
  }
  async claim(limit: number) {
    return this.queue.splice(0, limit);
  }
  async finish(
    itemId: string,
    ok: boolean,
    code: string | null,
    error: string | null,
    recipient: string | null,
  ) {
    this.finished.push({ itemId, ok, code, error, recipient });
  }
}

class FakeApi implements TransferApi {
  recipients: Record<string, unknown>[] = [];
  transfers: Record<string, unknown>[] = [];
  recipientRes: Awaited<ReturnType<TransferApi["createRecipient"]>> = {
    status: true,
    data: { recipient_code: "RCP_new" },
  };
  transferRes: Awaited<ReturnType<TransferApi["transfer"]>> = {
    status: true,
    data: { transfer_code: "TRF_1", status: "pending" },
  };
  throwOnTransfer = false;
  async createRecipient(body: Record<string, unknown>) {
    this.recipients.push(body);
    return this.recipientRes;
  }
  async transfer(body: Record<string, unknown>) {
    if (this.throwOnTransfer) throw new Error("socket hang up");
    this.transfers.push(body);
    return this.transferRes;
  }
}

function rig() {
  const db = new FakeDb();
  const api = new FakeApi();
  const ctx: PayoutCtx = { api, db };
  return { db, api, ctx };
}

describe("what is sent", () => {
  it("the reference is the item's own, so a repeat can never pay twice", () => {
    expect(transferReference(id)).toBe("po_123e4567e89b12d3a456426614174000");
    expect(transferReference(id)).toBe(transferReference(id.toUpperCase()));
    expect(transferReference(id)).toMatch(/^po_[0-9a-f]{32}$/);
  });

  it("the transfer body names the amount in kobo, the recipient and the reference", () => {
    const body = buildTransferBody(item(), "RCP_1");
    expect(body).toMatchObject({
      source: "balance",
      amount: 1408000,
      recipient: "RCP_1",
      currency: "NGN",
      reference: transferReference(id),
    });
  });

  it("the recipient is a Nigerian bank account", () => {
    expect(buildRecipientBody(item())).toEqual({
      type: "nuban",
      name: "Paws and Claws",
      account_number: "0123456789",
      bank_code: "058",
      currency: "NGN",
    });
  });
});

describe("judgeTransfer", () => {
  it("accepts success, pending and received", () => {
    for (const s of ["success", "pending", "received"]) {
      expect(judgeTransfer({ status: true, data: { transfer_code: "TRF_9", status: s } })).toEqual({
        ok: true,
        code: "TRF_9",
      });
    }
  });

  it("refuses failed, reversed and a transfer that wants an OTP", () => {
    for (const s of ["failed", "reversed", "abandoned"]) {
      expect(judgeTransfer({ status: true, data: { status: s } }).ok).toBe(false);
    }
    const otp = judgeTransfer({ status: true, data: { status: "otp" } });
    expect(otp.ok).toBe(false);
    expect(!otp.ok && otp.error).toContain("OTP");
  });

  it("a refusal carries Paystack's reason", () => {
    expect(judgeTransfer({ status: false, message: "Your balance is not enough" })).toEqual({
      ok: false,
      error: "Your balance is not enough",
    });
    expect(judgeTransfer({ status: false })).toEqual({
      ok: false,
      error: "Paystack refused the transfer",
    });
  });

  it("a duplicate reference means an earlier try got through", () => {
    const v = judgeTransfer({ status: false, message: "Duplicate Transfer Reference" });
    expect(v.ok).toBe(true);
  });
});

describe("accountProblem", () => {
  it("catches bad accounts before calling Paystack", () => {
    expect(accountProblem(item())).toBeNull();
    expect(accountProblem(item({ accountNumber: "12345" }))).toContain("10 digits");
    expect(accountProblem(item({ bankCode: "x" }))).toContain("bank code");
    expect(accountProblem(item({ amountKobo: 0 }))).toContain("amount");
    expect(accountProblem(item({ amountKobo: 10.5 }))).toContain("amount");
  });
});

describe("sendItem", () => {
  it("makes the recipient first, sends, and records the recipient for next time", async () => {
    const { db, api, ctx } = rig();
    expect(await sendItem(ctx, item())).toBe(true);
    expect(api.recipients).toHaveLength(1);
    expect(api.transfers[0]).toMatchObject({ recipient: "RCP_new", amount: 1408000 });
    expect(db.finished).toEqual([
      { itemId: id, ok: true, code: "TRF_1", error: null, recipient: "RCP_new" },
    ]);
  });

  it("reuses a known recipient", async () => {
    const { db, api, ctx } = rig();
    await sendItem(ctx, item({ recipientCode: "RCP_old" }));
    expect(api.recipients).toHaveLength(0);
    expect(api.transfers[0]).toMatchObject({ recipient: "RCP_old" });
    expect(db.finished[0].recipient).toBeNull();
  });

  it("a recipient that cannot be made fails the item without sending", async () => {
    const { db, api, ctx } = rig();
    api.recipientRes = { status: false, message: "Could not resolve account" };
    expect(await sendItem(ctx, item())).toBe(false);
    expect(api.transfers).toHaveLength(0);
    expect(db.finished[0]).toMatchObject({ ok: false, error: "Could not resolve account" });
  });

  it("a refused transfer fails the item but keeps the new recipient", async () => {
    const { db, api, ctx } = rig();
    api.transferRes = { status: false, message: "Your balance is not enough" };
    expect(await sendItem(ctx, item())).toBe(false);
    expect(db.finished[0]).toMatchObject({
      ok: false,
      error: "Your balance is not enough",
      recipient: "RCP_new",
    });
  });

  it("a bad account is failed without calling Paystack at all", async () => {
    const { db, api, ctx } = rig();
    expect(await sendItem(ctx, item({ accountNumber: "1" }))).toBe(false);
    expect(api.recipients).toHaveLength(0);
    expect(api.transfers).toHaveLength(0);
    expect(db.finished[0].error).toContain("10 digits");
  });

  it("a network failure records nothing, so the item is retried later with the same reference", async () => {
    const { db, api, ctx } = rig();
    api.throwOnTransfer = true;
    expect(await sendItem(ctx, item())).toBe(false);
    expect(db.finished).toHaveLength(0);
  });
});

describe("runPayouts", () => {
  it("schedules, then sends every claimed item and counts them", async () => {
    const { db, api, ctx } = rig();
    db.queue = [item(), item({ itemId: "other", partnerId: "p2" })];
    api.transferRes = { status: true, data: { transfer_code: "TRF_2", status: "success" } };
    expect(await runPayouts(ctx)).toEqual({ scheduled: true, sent: 2, failed: 0 });
    expect(api.transfers).toHaveLength(2);
  });

  it("one failure does not stop the others", async () => {
    const { db, api, ctx } = rig();
    db.queue = [item({ accountNumber: "bad" }), item({ itemId: "good" })];
    expect(await runPayouts(ctx)).toEqual({ scheduled: true, sent: 1, failed: 1 });
    expect(api.transfers).toHaveLength(1);
  });

  it("says when there was nothing to schedule or send", async () => {
    const { db, ctx } = rig();
    db.scheduled = null;
    expect(await runPayouts(ctx)).toEqual({ scheduled: false, sent: 0, failed: 0 });
  });
});

describe("parseTransferEvent", () => {
  const ev = (event: string, data: object) => JSON.stringify({ event, data });
  it("reads failed, reversed and success", () => {
    expect(
      parseTransferEvent(
        ev("transfer.failed", { transfer_code: "TRF_1", reason: "Account closed" }),
      ),
    ).toEqual({
      kind: "failed",
      transferCode: "TRF_1",
      reason: "Account closed",
    });
    expect(parseTransferEvent(ev("transfer.reversed", { transfer_code: "TRF_1" }))?.kind).toBe(
      "failed",
    );
    expect(parseTransferEvent(ev("transfer.success", { transfer_code: "TRF_1" }))?.kind).toBe(
      "success",
    );
  });

  it("ignores anything else", () => {
    expect(parseTransferEvent("not json")).toBeNull();
    expect(parseTransferEvent(ev("charge.success", { reference: "pp_x" }))).toBeNull();
    expect(parseTransferEvent(ev("transfer.failed", {}))).toBeNull();
    expect(parseTransferEvent("null")).toBeNull();
  });
});
