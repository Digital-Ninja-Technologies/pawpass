"use server";

import { runRpc, text, type ActionState } from "./helpers";

export async function widenAlert(_prev: ActionState, form: FormData): Promise<ActionState> {
  const metres = Number(text(form, "radius_m"));
  if (!Number.isInteger(metres) || metres <= 0) return { ok: false, message: "Invalid radius." };
  return runRpc(
    "lost_alerts",
    "admin_widen_lost_alert",
    { p_alert: text(form, "alert"), p_radius_m: metres },
    { paths: ["/lost-found"], success: `Alert widened to ${metres / 1000} km.` },
  );
}

export async function setOrderStatus(_prev: ActionState, form: FormData): Promise<ActionState> {
  const status = text(form, "status");
  return runRpc(
    "lost_alerts",
    "admin_set_qr_order_status",
    { p_order: text(form, "order"), p_status: status },
    { paths: ["/lost-found", "/support"], success: `Order marked ${status}.` },
  );
}
