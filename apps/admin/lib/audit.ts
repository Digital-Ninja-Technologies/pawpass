import type { SupabaseClient } from "@supabase/supabase-js";
import type { AuditRow } from "./types";
import { formatKobo } from "./format";

export type NameMap = Record<string, string>;

/** Looks up readable names for the things audit rows point at (partners, disputes, users...). */
export async function resolveAuditNames(
  supabase: SupabaseClient,
  rows: AuditRow[],
): Promise<NameMap> {
  const ids = (type: string) => [
    ...new Set(rows.filter((r) => r.target_type === type && r.target_id).map((r) => r.target_id!)),
  ];
  const names: NameMap = {};
  const partners = ids("partner_account");
  const disputes = ids("dispute");
  const users = ids("user");
  const tickets = ids("support_ticket");
  const [p, d, u, t] = await Promise.all([
    partners.length
      ? supabase.from("admin_kyc_v").select("id, business_name").in("id", partners)
      : null,
    disputes.length ? supabase.from("admin_dispute_v").select("id, ref").in("id", disputes) : null,
    users.length
      ? supabase
          .from("admin_directory_v")
          .select("user_id, name")
          .eq("kind", "owner")
          .in("user_id", users)
      : null,
    tickets.length ? supabase.from("admin_support_v").select("id, ref").in("id", tickets) : null,
  ]);
  for (const r of p?.data ?? []) names[r.id] = r.business_name;
  for (const r of d?.data ?? []) names[r.id] = r.ref;
  for (const r of u?.data ?? []) names[r.user_id] = r.name;
  for (const r of t?.data ?? []) names[r.id] = `#${r.ref}`;
  return names;
}

/** One plain sentence for an audit row, e.g. "approved Glam Paws Grooming". */
export function describeAudit(
  row: Pick<AuditRow, "action" | "target_id" | "details">,
  names: NameMap = {},
): string {
  const who = row.target_id ? names[row.target_id] : undefined;
  const d = row.details ?? {};
  const note = typeof d.note === "string" && d.note ? `: "${d.note}"` : "";
  switch (row.action) {
    case "partner.approve":
      return `approved ${who ?? "a partner"}`;
    case "partner.reject":
      return `rejected ${who ?? "a partner"}${note}`;
    case "partner.needs_info":
      return `asked ${who ?? "a partner"} for more information${note}`;
    case "partner.review_notes":
      return `updated review notes for ${who ?? "a partner"}`;
    case "dispute.refund":
      return (
        `refunded dispute ${who ?? ""}`.trim() +
        (typeof d.amount_kobo === "number" ? ` (${formatKobo(d.amount_kobo)})` : "")
      );
    case "dispute.split":
      return (
        `split dispute ${who ?? ""}`.trim() +
        (typeof d.refund_kobo === "number" ? `, refunding ${formatKobo(d.refund_kobo)}` : "")
      );
    case "dispute.release":
      return `released money to the partner on dispute ${who ?? ""}`.trim();
    case "report.remove_and_suspend":
      return `removed reported content and suspended the account${note}`;
    case "report.remove":
      return `removed reported content${note}`;
    case "report.keep":
      return `kept reported content${note}`;
    case "user.suspend":
      return `suspended ${who ?? "an account"}${typeof d.reason === "string" ? `: "${d.reason}"` : ""}`;
    case "user.unsuspend":
      return `restored ${who ?? "an account"}`;
    case "user.view_email":
      return `viewed the email address of ${who ?? "a user"}`;
    case "payout_run.prepare":
      return `prepared the payout run${typeof d.total_kobo === "number" ? ` (${formatKobo(d.total_kobo)})` : ""}`;
    case "payout_run.approve":
      return "approved the payout run";
    case "settings.update":
      return "changed settings";
    case "staff.invite":
      return `invited ${typeof d.email === "string" ? d.email : "a team member"} as ${String(d.role ?? "staff").replace(/_/g, " ")}`;
    case "staff.invite_revoke":
      return "revoked a team invite";
    case "staff.accept_invite":
      return `accepted an invite as ${String(d.role ?? "staff").replace(/_/g, " ")}`;
    case "staff.role":
      return `changed a team role from ${String(d.from ?? "").replace(/_/g, " ")} to ${String(d.to ?? "").replace(/_/g, " ")}`;
    case "staff.status":
      return `${d.to === "suspended" ? "suspended" : "restored"} a team member`;
    case "lost_alert.widen":
      return `widened a lost alert from ${Number(d.from_m) / 1000} km to ${Number(d.to_m) / 1000} km`;
    case "qr_order.shipped":
      return "marked a QR tag order as shipped";
    case "qr_order.delivered":
      return "marked a QR tag order as delivered";
    case "ticket.reply":
      return `replied to ticket ${who ?? ""}`.trim();
    case "ticket.note":
      return `added an internal note to ticket ${who ?? ""}`.trim();
    case "ticket.status":
      return `changed the status of ticket ${who ?? ""}`.trim();
    default:
      return row.action.replace(/[._]/g, " ");
  }
}
