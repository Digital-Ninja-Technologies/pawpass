"use server";

import { runRpc, text, type ActionState } from "./helpers";

export async function reply(_prev: ActionState, form: FormData): Promise<ActionState> {
  const internal = text(form, "mode") === "note";
  return runRpc(
    "support_reply",
    "admin_reply_ticket",
    { p_ticket: text(form, "ticket"), p_body: text(form, "body"), p_internal: internal },
    { paths: ["/support", "/"], success: internal ? "Note added." : "Reply sent." },
  );
}

export async function setTicketStatus(_prev: ActionState, form: FormData): Promise<ActionState> {
  return runRpc(
    "support_reply",
    "admin_set_ticket_status",
    { p_ticket: text(form, "ticket"), p_status: text(form, "status") },
    { paths: ["/support", "/"], success: "Ticket updated." },
  );
}
