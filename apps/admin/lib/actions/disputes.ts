"use server";

import { revalidatePath } from "next/cache";
import { requireAction } from "../auth";
import { parseNairaToKobo } from "../format";
import { flash, friendly, text, type ActionState } from "./helpers";

export async function decideDispute(_prev: ActionState, form: FormData): Promise<ActionState> {
  const ctx = await requireAction("decide_dispute");
  if ("error" in ctx) return { ok: false, message: ctx.error };

  const decision = text(form, "decision");
  let refund: number | null = null;
  if (decision === "split") {
    refund = parseNairaToKobo(text(form, "refund"));
    if (refund === null)
      return { ok: false, message: "Enter the refund amount in naira, for example 190,000." };
  }
  const { error } = await ctx.supabase.rpc("admin_decide_dispute", {
    p_dispute: text(form, "dispute"),
    p_decision: decision,
    p_refund_kobo: refund,
    p_note: text(form, "note"),
  });
  if (error) return { ok: false, message: friendly(error.message) };
  revalidatePath("/disputes");
  revalidatePath("/payouts");
  revalidatePath("/");
  const message = "Decision recorded. The payout is no longer paused.";
  await flash(message);
  return { ok: true, message };
}
