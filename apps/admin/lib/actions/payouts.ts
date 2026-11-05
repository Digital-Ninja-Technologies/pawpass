"use server";

import { runRpc, text, type ActionState } from "./helpers";

export async function prepareRun(_prev: ActionState, form: FormData): Promise<ActionState> {
  const date = text(form, "run_on");
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return { ok: false, message: "Pick a valid run date." };
  return runRpc(
    "prepare_payout",
    "admin_prepare_payout_run",
    { p_run_on: date },
    {
      paths: ["/payouts/run", "/payouts"],
      success: "Payout run prepared from the money that is ready.",
    },
  );
}

export async function approveRun(_prev: ActionState, form: FormData): Promise<ActionState> {
  return runRpc(
    "prepare_payout",
    "admin_approve_payout_run",
    { p_run: text(form, "run") },
    {
      paths: ["/payouts/run", "/payouts", "/"],
      success: "Payout run approved. It will be sent on the run day.",
    },
  );
}
