"use server";

import { revalidatePath } from "next/cache";
import { requireAction } from "../auth";
import { KYC_CHECKS } from "../kyc";
import { flash, friendly, text, type ActionState } from "./helpers";

/** One form, four buttons: save notes, approve, ask for more info, reject. */
export async function reviewPartner(_prev: ActionState, form: FormData): Promise<ActionState> {
  const ctx = await requireAction("review_partner");
  if ("error" in ctx) return { ok: false, message: ctx.error };

  const partner = text(form, "partner");
  const intent = text(form, "intent");
  const checks = Object.fromEntries(
    KYC_CHECKS.map((c) => [c.key, form.get(`check_${c.key}`) === "on"]),
  );

  const saved = await ctx.supabase.rpc("admin_save_kyc_review", {
    p_partner: partner,
    p_checks: checks,
    p_internal_note: text(form, "internal_note"),
  });
  if (saved.error) return { ok: false, message: friendly(saved.error.message) };
  if (intent === "save") {
    revalidatePath("/verifications");
    return { ok: true, message: "Review notes saved." };
  }

  const decided = await ctx.supabase.rpc("admin_review_partner", {
    p_partner: partner,
    p_decision: intent,
    p_note: text(form, "message"),
  });
  if (decided.error) return { ok: false, message: friendly(decided.error.message) };

  revalidatePath("/verifications");
  revalidatePath("/");
  const done = {
    approve: "Approved. The partner now has the verified badge.",
    needs_info: "Asked the partner for more information.",
    reject: "Application rejected.",
  } as const;
  const message = done[intent as keyof typeof done] ?? "Done.";
  await flash(message);
  return { ok: true, message };
}
