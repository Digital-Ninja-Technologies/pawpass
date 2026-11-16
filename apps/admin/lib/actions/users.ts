"use server";

import { revalidatePath } from "next/cache";
import { requireAction, type Staff } from "../auth";
import { deletionErrorMessage, deletionFunctionUrl, emailMatches } from "../account-deletion";
import { supabaseEnv } from "../supabase/env";
import { flash, friendly, runRpc, text, type ActionState } from "./helpers";

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

/**
 * Deletes a person's account because they asked (usually by email). Full admins only. The admin gives a reason and types
 * the account's email; then the admin-delete-account function, which holds the service key, does the erasing and writes
 * the audit row. This console never holds that key.
 */
export async function deleteUserAccount(_prev: ActionState, form: FormData): Promise<ActionState> {
  const ctx = await requireAction("delete_account");
  if ("error" in ctx) return { ok: false, message: ctx.error };
  const staff = ctx as Staff;

  const user = text(form, "user");
  const reason = text(form, "reason");
  if (reason.length < 3) return { ok: false, message: "Give a reason of at least 3 characters." };
  if (reason.length > 300) return { ok: false, message: "Keep the reason under 300 characters." };

  const res = await staff.supabase.rpc("admin_user_email", { p_user: user });
  if (res.error) return { ok: false, message: friendly(res.error.message) };
  if (!emailMatches(text(form, "confirm_email"), res.data as string | null)) {
    return { ok: false, message: "The email you typed does not match this account." };
  }

  const {
    data: { session },
  } = await staff.supabase.auth.getSession();
  if (!session) return { ok: false, message: "Your session has ended. Sign in again." };

  const { url, key } = supabaseEnv();
  let response: Response;
  try {
    response = await fetch(deletionFunctionUrl(url), {
      method: "POST",
      headers: { Authorization: `Bearer ${session.access_token}`, apikey: key, "Content-Type": "application/json" },
      body: JSON.stringify({ user, reason }),
      cache: "no-store",
    });
  } catch {
    return { ok: false, message: "Could not reach the server. Check the connection and try again." };
  }
  const body = await response.json().catch(() => null);
  if (!response.ok) return { ok: false, message: deletionErrorMessage(response.status, body) };

  for (const p of ["/users", "/reports", "/"]) revalidatePath(p);
  const message = "Account deleted. Their personal data is erased and the sign in is removed.";
  await flash(message);
  return { ok: true, message };
}
