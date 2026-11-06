// The weekly payout, written against small interfaces so it can be tested without Paystack or a database.
// The database decides what is owed (the `claim_payout_items` function moves the money to "released" first, so a
// dispute can no longer pause it); this only asks Paystack to send it, and records how that went.

export interface PayoutItem {
  itemId: string;
  partnerId: string;
  amountKobo: number;
  bankCode: string;
  accountNumber: string;
  accountName: string;
  /** Paystack's id for this bank account, once one has been made. */
  recipientCode: string | null;
  attempts: number;
}

export interface TransferApi {
  createRecipient(
    body: Record<string, unknown>,
  ): Promise<{ status?: boolean; message?: string; data?: { recipient_code?: string } | null }>;
  transfer(body: Record<string, unknown>): Promise<{
    status?: boolean;
    message?: string;
    data?: { transfer_code?: string; status?: string } | null;
  }>;
}

export interface PayoutDb {
  /** Makes or refreshes the draft run for the next payout day. */
  schedule(): Promise<string | null>;
  /** Items of approved runs that are due. Money is already released when they come back. */
  claim(limit: number): Promise<PayoutItem[]>;
  finish(
    itemId: string,
    ok: boolean,
    transferCode: string | null,
    error: string | null,
    recipientCode: string | null,
  ): Promise<void>;
}

export interface PayoutCtx {
  api: TransferApi;
  db: PayoutDb;
}

/**
 * One reference per payout item, always the same for that item: if a send is retried after the first one actually
 * went through, Paystack refuses the duplicate instead of paying twice. 35 characters, lower case.
 */
export function transferReference(itemId: string): string {
  return "po_" + itemId.replace(/-/g, "").toLowerCase();
}

export function buildRecipientBody(item: PayoutItem): Record<string, unknown> {
  return {
    type: "nuban",
    name: item.accountName,
    account_number: item.accountNumber,
    bank_code: item.bankCode,
    currency: "NGN",
  };
}

export function buildTransferBody(item: PayoutItem, recipient: string): Record<string, unknown> {
  return {
    source: "balance",
    amount: item.amountKobo,
    recipient,
    reason: "PawPass weekly payout",
    currency: "NGN",
    reference: transferReference(item.itemId),
  };
}

export type TransferVerdict =
  { ok: true; code: string | null; note?: string } | { ok: false; error: string };

/** Paystack accepts a transfer as success, pending or received. Anything else is a failure to record. */
export function judgeTransfer(res: {
  status?: unknown;
  message?: unknown;
  data?: { transfer_code?: unknown; status?: unknown } | null;
}): TransferVerdict {
  const message = typeof res.message === "string" ? res.message : "";
  if (res.status !== true) {
    // The same reference twice means an earlier attempt did reach Paystack. Do not send again.
    if (/duplicate/i.test(message)) {
      return {
        ok: true,
        code: null,
        note: "Paystack already had this transfer. Check it in the dashboard.",
      };
    }
    return { ok: false, error: message || "Paystack refused the transfer" };
  }
  const state = res.data?.status;
  const code = typeof res.data?.transfer_code === "string" ? res.data.transfer_code : null;
  if (state === "otp") {
    return {
      ok: false,
      error: "Paystack is asking for an OTP. Turn off transfer OTP in the Paystack settings.",
    };
  }
  if (state === "failed" || state === "reversed" || state === "abandoned") {
    return { ok: false, error: `Paystack transfer status: ${String(state)}` };
  }
  return { ok: true, code };
}

/** Looks only at the shape of a bank account, before bothering Paystack. */
export function accountProblem(item: PayoutItem): string | null {
  if (!/^\d{10}$/.test(item.accountNumber)) return "The account number is not 10 digits";
  if (!/^\d{3,6}$/.test(item.bankCode)) return "The bank code is not valid";
  if (!Number.isInteger(item.amountKobo) || item.amountKobo <= 0) return "The amount is not valid";
  return null;
}

/** Sends one item. Never throws: a failure is recorded on the item so the next run can try again. */
export async function sendItem(ctx: PayoutCtx, item: PayoutItem): Promise<boolean> {
  let recipient = item.recipientCode;
  let newRecipient: string | null = null;
  try {
    const bad = accountProblem(item);
    if (bad) {
      await ctx.db.finish(item.itemId, false, null, bad, null);
      return false;
    }
    if (!recipient) {
      const res = await ctx.api.createRecipient(buildRecipientBody(item));
      const code = res.data?.recipient_code;
      if (res.status !== true || !code) {
        await ctx.db.finish(
          item.itemId,
          false,
          null,
          res.message || "Paystack could not add the bank account",
          null,
        );
        return false;
      }
      recipient = code;
      newRecipient = code;
    }
    const verdict = judgeTransfer(await ctx.api.transfer(buildTransferBody(item, recipient)));
    if (verdict.ok) {
      await ctx.db.finish(item.itemId, true, verdict.code, verdict.note ?? null, newRecipient);
      return true;
    }
    await ctx.db.finish(item.itemId, false, null, verdict.error, newRecipient);
    return false;
  } catch (e) {
    // Network trouble: the item stays "sending" and is handed out again after 15 minutes, with the same reference.
    console.error("payout send failed", item.itemId, e);
    return false;
  }
}

/** The scheduled job: keep the draft for the next payout day fresh, then send whatever staff approved. */
export async function runPayouts(
  ctx: PayoutCtx,
  limit = 20,
): Promise<{ scheduled: boolean; sent: number; failed: number }> {
  const scheduled = (await ctx.db.schedule()) !== null;
  const items = await ctx.db.claim(limit);
  let sent = 0;
  let failed = 0;
  for (const item of items) {
    if (await sendItem(ctx, item)) sent++;
    else failed++;
  }
  return { scheduled, sent, failed };
}

export interface TransferEvent {
  kind: "failed" | "success";
  transferCode: string;
  reason: string | null;
}

/** A `transfer.*` webhook, or null for anything else. */
export function parseTransferEvent(raw: string): TransferEvent | null {
  let event: unknown;
  try {
    event = JSON.parse(raw);
  } catch {
    return null;
  }
  if (typeof event !== "object" || event === null) return null;
  const e = event as { event?: unknown; data?: Record<string, unknown> };
  const name = e.event;
  if (name !== "transfer.failed" && name !== "transfer.reversed" && name !== "transfer.success")
    return null;
  const code = e.data?.transfer_code;
  if (typeof code !== "string" || !code) return null;
  const reason = e.data?.reason;
  return {
    kind: name === "transfer.success" ? "success" : "failed",
    transferCode: code,
    reason: typeof reason === "string" ? reason : null,
  };
}
