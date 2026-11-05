"use server";

import { redirect } from "next/navigation";
import { createClient } from "../supabase/server";
import { isRole } from "../roles";
import type { MeRow } from "../types";
import type { ActionState } from "./helpers";
import { safeNext } from "../safe-next";

export async function signIn(_prev: ActionState, form: FormData): Promise<ActionState> {
  const email = String(form.get("email") ?? "")
    .trim()
    .toLowerCase();
  const password = String(form.get("password") ?? "");
  if (!email || !password) return { ok: false, message: "Enter your work email and password." };

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) {
    // Wrong credentials and unknown emails share one message, so the form cannot be used to find accounts.
    if (error.code === "invalid_credentials" || error.status === 400) {
      return { ok: false, message: "That email and password did not match. Try again." };
    }
    if (error.code === "user_banned")
      return { ok: false, message: "This account has been suspended." };
    return {
      ok: false,
      message: "We could not sign you in just now. Check your connection and try again.",
    };
  }

  const { data: me } = await supabase.from("admin_me_v").select("*").maybeSingle<MeRow>();
  if (!me || me.status !== "active" || !isRole(me.role)) {
    await supabase.auth.signOut();
    return {
      ok: false,
      message: "This account does not have admin access. Ask your team lead for an invite.",
    };
  }
  redirect(safeNext(String(form.get("next") ?? "")));
}

export async function signOut(): Promise<void> {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/login");
}
