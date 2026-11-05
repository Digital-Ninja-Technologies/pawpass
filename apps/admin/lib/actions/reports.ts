"use server";

import { runRpc, text, type ActionState } from "./helpers";

export async function resolveReport(_prev: ActionState, form: FormData): Promise<ActionState> {
  const action = text(form, "action");
  const done: Record<string, string> = {
    remove_and_suspend: "Content removed and the account suspended.",
    remove: "Content removed.",
    keep: "Kept. The reports are dismissed.",
  };
  return runRpc(
    "resolve_report",
    "admin_resolve_report",
    {
      p_target_type: text(form, "target_type"),
      p_target_id: text(form, "target_id"),
      p_action: action,
      p_note: text(form, "note"),
    },
    { paths: ["/reports", "/", "/users"], success: done[action] ?? "Done." },
  );
}
