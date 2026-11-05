"use server";

import { runRpc, text, type ActionState } from "./helpers";

function num(form: FormData, key: string): number | null {
  const raw = text(form, key).replace(",", ".");
  if (raw === "") return null;
  const n = Number(raw);
  return Number.isFinite(n) ? n : null;
}

export async function updateSettings(_prev: ActionState, form: FormData): Promise<ActionState> {
  const values: Record<string, number> = {};
  const set = (key: string, v: number | null, scale = 1) => {
    if (v !== null) values[key] = Math.round(v * scale);
  };

  const commission = num(form, "commission");
  const escrowFee = num(form, "escrow_fee");
  if ([commission, escrowFee].some((v) => v !== null && (v < 0 || v > 100)))
    return { ok: false, message: "Percentages must be between 0 and 100." };
  set("booking_commission_bps", commission, 100);
  set("puppy_escrow_fee_bps", escrowFee, 100);

  // The deposit is one third. Only overwrite the exact fraction when the field was actually changed.
  const deposit = num(form, "deposit");
  if (deposit !== null && text(form, "deposit") !== text(form, "deposit_initial")) {
    if (deposit <= 0 || deposit > 100)
      return { ok: false, message: "The deposit share must be above 0 and at most 100." };
    values.deposit_fraction = deposit / 100;
  }
  set("vet_check_hours", num(form, "vet_check_hours"));
  set("free_cancel_hours", num(form, "free_cancel_hours"));
  set("kyc_target_hours", num(form, "kyc_target_hours"));
  set("lost_radius_m", num(form, "lost_radius_km"), 1000);
  set("lost_autoclose_days", num(form, "lost_autoclose_days"));
  set("payout_weekday", num(form, "payout_weekday"));

  return runRpc(
    "edit_settings",
    "admin_update_settings",
    { p_values: values },
    {
      paths: ["/settings", "/"],
      success: "Settings saved. They apply to new bookings and listings.",
    },
  );
}

export async function setStaffRole(_prev: ActionState, form: FormData): Promise<ActionState> {
  return runRpc(
    "manage_team",
    "admin_set_staff_role",
    { p_staff: text(form, "staff"), p_role: text(form, "role") },
    { paths: ["/settings"], success: "Role updated." },
  );
}

export async function setStaffStatus(_prev: ActionState, form: FormData): Promise<ActionState> {
  const status = text(form, "status");
  return runRpc(
    "manage_team",
    "admin_set_staff_status",
    { p_staff: text(form, "staff"), p_status: status },
    {
      paths: ["/settings"],
      success: status === "suspended" ? "Access suspended." : "Access restored.",
    },
  );
}

export async function revokeInvite(_prev: ActionState, form: FormData): Promise<ActionState> {
  return runRpc(
    "manage_team",
    "admin_revoke_staff_invite",
    { p_invite: text(form, "invite") },
    { paths: ["/settings"], success: "Invite revoked." },
  );
}
