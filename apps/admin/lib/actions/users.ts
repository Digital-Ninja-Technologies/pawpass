"use server";

import { runRpc, text, type ActionState } from "./helpers";

export async function setSuspended(_prev: ActionState, form: FormData): Promise<ActionState> {
  const suspend = text(form, "suspend") === "true";
  return runRpc(
    "suspend_user",
    "admin_set_user_suspended",
    { p_user: text(form, "user"), p_suspended: suspend, p_reason: text(form, "reason") },
    {
      paths: ["/users", "/reports", "/"],
      success: suspend
        ? "Account suspended. They are signed out and cannot sign in."
        : "Account restored.",
    },
  );
}
